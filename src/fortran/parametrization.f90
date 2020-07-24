!  This file is part of XOPTFOIL.

!  XOPTFOIL is free software: you can redistribute it and/or modify
!  it under the terms of the GNU General Public License as published by
!  the Free Software Foundation, either version 3 of the License, or
!  (at your option) any later version.

!  XOPTFOIL is distributed in the hope that it will be useful,
!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!  GNU General Public License for more details.

!  You should have received a copy of the GNU General Public License
!  along with XOPTFOIL.  If not, see <http://www.gnu.org/licenses/>.

!  Copyright (C) 2017-2019 Daniel Prosser

module parametrization

! Contains subroutines to create an airfoil shape from design variables

  implicit none

! Shape functions for creating airfoil shapes (top and bottom)

  double precision, dimension(:,:), pointer :: top_shape_function
  double precision, dimension(:,:), pointer :: bot_shape_function

!$omp threadprivate(top_shape_function)
!$omp threadprivate(bot_shape_function)

  contains

!=============================================================================80
!
! Allocates memory for shape functions
!
!=============================================================================80
subroutine allocate_shape_functions(nmodest, nmodesb, npointst, npointsb)

  integer, intent(in) :: nmodest, nmodesb, npointst, npointsb

  allocate(top_shape_function(nmodest,npointst))
  allocate(bot_shape_function(nmodesb,npointsb))

end subroutine allocate_shape_functions

!=============================================================================80
!
! Deallocates memory for shape functions
!
!=============================================================================80
subroutine deallocate_shape_functions

  deallocate(top_shape_function)
  deallocate(bot_shape_function)

end subroutine deallocate_shape_functions

!=============================================================================80
!
! Creates shape functions for top and bottom surfaces
! shapetype may be 'naca' or 'hicks-henne'
! For Hicks-Hene shape functions, number of elements in modes must be a 
! multiple of 3.
!
!=============================================================================80
subroutine create_shape_functions(xtop, xbot, modestop, modesbot, shapetype,   &
                                  first_time)

  double precision, dimension(:), intent(in) :: xtop, xbot, modestop, modesbot
  character(*), intent(in) :: shapetype
  logical, intent(in) :: first_time

  integer :: nmodestop, nmodesbot, ntop, nbot

  ntop = size(xtop,1)
  nbot = size(xbot,1)

  if (trim(shapetype) == 'naca') then
    nmodestop = size(modestop,1)
    nmodesbot = size(modesbot,1)
  else
    nmodestop = size(modestop,1)/3
    nmodesbot = size(modesbot,1)/3
  end if

  if (first_time) then

!   Allocate shape functions

    call allocate_shape_functions(nmodestop, nmodesbot, ntop, nbot)

!   Initialize shape functions

    top_shape_function(:,:) = 0.d0
    bot_shape_function(:,:) = 0.d0

  end if

  if ((.not. first_time) .or. (trim(shapetype) == 'naca')) then

!   Create shape functions for top

    call create_shape(xtop, modestop, shapetype, top_shape_function)

!   Create shape functions for bottom

    call create_shape(xbot, modesbot, shapetype, bot_shape_function)

  end if

end subroutine create_shape_functions

!=============================================================================80
!
! Calculates number of parametrization design variables from top and botton 
! input parameters depending on parametrization type
!
!=============================================================================80
subroutine parametrization_dvs(nparams_top, nparams_bot, parametrization_type, &
                               ndvs_top, ndvs_bot)

  integer, intent(in) :: nparams_top, nparams_bot
  character(*), intent(in) :: parametrization_type
  
  integer, intent(out) :: ndvs_top, ndvs_bot

  if (trim(parametrization_type) == 'naca') then
    
    ndvs_top = nparams_top
    ndvs_bot = nparams_bot
    
  elseif (trim(parametrization_type) == 'hicks-henne') then
    
    ndvs_top = nparams_top*3
    ndvs_bot = nparams_bot*3
    
  else

    write(*,*)
    write(*,*) 'Shape function '//trim(parametrization_type)//' not recognized.'
    write(*,*)
    stop

  end if 

end subroutine parametrization_dvs

!=============================================================================80
!
! Sets number of constrained design variables based on parametrization
!
!=============================================================================80
subroutine parametrization_constrained_dvs(parametrization_type,               &
    constrained_dvs, nflap_optimize, int_x_flap_spec, nfunctions_top,          &
    nfunctions_bot, nbot_actual, symmetrical)

  character(*), intent(in) :: parametrization_type
  integer, intent(in) :: nflap_optimize
  integer, intent(in) :: int_x_flap_spec
  logical, intent(in) :: symmetrical
  integer, intent(out) :: nfunctions_top, nfunctions_bot
  integer, dimension(:), allocatable, intent(inout) :: constrained_dvs
  integer :: i, counter, idx, nbot_actual


  !   The number of bottom shape functions actually used (0 for symmetrical)

  if (symmetrical) then
    nbot_actual = 0
  else
    nbot_actual = nfunctions_bot
  end if
    
  !   Set design variables with side constraints

  if (trim(parametrization_type) == 'naca') then

    !     For NACA, we will only constrain the flap deflection

    allocate(constrained_dvs(nflap_optimize + int_x_flap_spec))
    counter = 0
    do i = nfunctions_top + nbot_actual + 1,                                   &
            nfunctions_top + nbot_actual + nflap_optimize + int_x_flap_spec
      counter = counter + 1
      constrained_dvs(counter) = i
    end do
    
  elseif (trim(parametrization_type) == 'hicks-henne') then

    !     For Hicks-Henne, also constrain bump locations and width

    allocate(constrained_dvs(2*nfunctions_top + 2*nbot_actual +                &
                              nflap_optimize + int_x_flap_spec))
    counter = 0
    do i = 1, nfunctions_top + nbot_actual
      counter = counter + 1
      idx = 3*(i-1) + 2      ! DV index of bump location, shape function i
      constrained_dvs(counter) = idx
      counter = counter + 1
      idx = 3*(i-1) + 3      ! Index of bump width, shape function i
      constrained_dvs(counter) = idx
    end do
    
    do i = 3*(nfunctions_top + nbot_actual) + 1,                               &
            3*(nfunctions_top + nbot_actual) + nflap_optimize + int_x_flap_spec
      counter = counter + 1
      constrained_dvs(counter) = i
    end do
    
  else

    write(*,*)
    write(*,*) 'Shape function '//trim(parametrization_type)//' not recognized.'
    write(*,*)
    stop
      
  end if

end subroutine parametrization_constrained_dvs


!=============================================================================80
!
! Initialize parametrization 
! Set X0 before optimization
!
!=============================================================================80
subroutine parametrization_init(optdesign, x0)

  use vardef,             only : shape_functions, nflap_optimize,              &
                                 initial_perturb, min_flap_degrees,            &
                                 max_flap_degrees, flap_degrees, x_flap,       &
                                 int_x_flap_spec, min_flap_x, max_flap_x,      &
                                 flap_optimize_points, min_bump_width

  double precision, dimension(:), intent(inout) :: optdesign
  double precision, dimension(size(optdesign,1)), intent(out) :: x0

  integer :: i, counter, nfuncs, oppoint, ndv
  double precision :: t1fact, t2fact, ffact, fxfact
  
  ndv = size(optdesign,1)
  
  t1fact = initial_perturb/(1.d0 - 0.001d0)
  t2fact = initial_perturb/(10.d0 - min_bump_width)
  ffact = initial_perturb/(max_flap_degrees - min_flap_degrees)
  fxfact = initial_perturb/(max_flap_x - min_flap_x)
  
  if (trim(shape_functions) == 'naca') then     

    nfuncs = ndv - nflap_optimize - int_x_flap_spec

  !   Mode strength = 0 (aka seed airfoil)

    x0(1:nfuncs) = 0.d0

  !   Seed flap deflection as specified in input file

    do i = nfuncs + 1, ndv - int_x_flap_spec
      oppoint = flap_optimize_points(i-nfuncs)
      x0(i) = flap_degrees(oppoint)*ffact
    end do
    if (int_x_flap_spec == 1) x0(ndv) = (x_flap - min_flap_x) * fxfact
    
  elseif (trim(shape_functions) == 'hicks-henne') then

    nfuncs = (ndv - nflap_optimize - int_x_flap_spec)/3

  !   Bump strength = 0 (aka seed airfoil)

    do i = 1, nfuncs
      counter = 3*(i-1)
      x0(counter+1) = 0.d0
      x0(counter+2) = 0.5d0*t1fact
      x0(counter+3) = 1.d0*t2fact
    end do
    do i = 3*nfuncs+1, ndv - int_x_flap_spec
      oppoint = flap_optimize_points(i-3*nfuncs)
      x0(i) = flap_degrees(oppoint)*ffact
    end do
    if (int_x_flap_spec == 1) x0(ndv) = (x_flap - min_flap_x) * fxfact
  
  else

    write(*,*)
    write(*,*) 'Shape function '//trim(shape_functions)//' not recognized.'
    write(*,*)
    stop
      
  end if

end subroutine parametrization_init
!=============================================================================80
!
! Initialize parametrization 
! Set xmax and xmin before optimization
!
!=============================================================================80
subroutine parametrization_maxmin(optdesign, xmin, xmax)

  use vardef,             only : shape_functions, nflap_optimize,              &
                                 initial_perturb, min_flap_degrees,            &
                                 max_flap_degrees, flap_degrees, x_flap,       &
                                 int_x_flap_spec, min_flap_x, max_flap_x,      &
                                 flap_optimize_points, min_bump_width
  
  double precision, dimension(:), intent(in) :: optdesign
  double precision, dimension(size(optdesign,1)), intent(out) :: xmin, xmax

  integer :: i, counter, nfuncs, ndv
  double precision :: t1fact, t2fact, ffact, fxfact
  
  ndv = size(optdesign,1)
  
  t1fact = initial_perturb/(1.d0 - 0.001d0)
  t2fact = initial_perturb/(10.d0 - min_bump_width)
  ffact = initial_perturb/(max_flap_degrees - min_flap_degrees)
  fxfact = initial_perturb/(max_flap_x - min_flap_x)
    
  if (trim(shape_functions) == 'naca') then

    nfuncs = ndv - nflap_optimize

    xmin(1:nfuncs) = -0.5d0*initial_perturb
    xmax(1:nfuncs) = 0.5d0*initial_perturb
    xmin(nfuncs+1:ndv-int_x_flap_spec) = min_flap_degrees*ffact
    xmax(nfuncs+1:ndv-int_x_flap_spec) = max_flap_degrees*ffact
    if (int_x_flap_spec == 1) then
      xmin(ndv) = (min_flap_x - min_flap_x)*fxfact
      xmax(ndv) = (max_flap_x - min_flap_x)*fxfact
    end if

  elseif (trim(shape_functions) == 'hicks-henne') then

    nfuncs = (ndv - nflap_optimize - nflap_optimize)/3

    do i = 1, nfuncs
      counter = 3*(i-1)
      xmin(counter+1) = -initial_perturb/2.d0
      xmax(counter+1) = initial_perturb/2.d0
      xmin(counter+2) = 0.0001d0*t1fact
      xmax(counter+2) = 1.d0*t1fact
      xmin(counter+3) = min_bump_width*t2fact
      xmax(counter+3) = 10.d0*t2fact
    end do
    do i = 3*nfuncs+1, ndv - int_x_flap_spec 
      xmin(i) = min_flap_degrees*ffact
      xmax(i) = max_flap_degrees*ffact
    end do
    if (int_x_flap_spec == 1) then
      xmin(ndv) = (min_flap_x - min_flap_x)*fxfact
      xmax(ndv) = (max_flap_x - min_flap_x)*fxfact
    end if
  
  else

    write(*,*)
    write(*,*) 'Shape function '//trim(shape_functions)//' not recognized.'
    write(*,*)
    stop
      
  end if
end subroutine parametrization_maxmin
!=============================================================================80
!
! Populates shape function arrays
! For Hicks-Hene shape functions, number of elements in modes must be a 
! multiple of 3.
!
!=============================================================================80
subroutine create_shape(x, modes, shapetype, shape_function)

  double precision, dimension(:), intent(in) :: x, modes
  character(*), intent(in) :: shapetype
  double precision, dimension(:,:), intent(inout) :: shape_function

  shape_switch: if (trim(shapetype) == 'naca') then
    
    call NACA_shape(x, modes, shape_function)
    
  elseif (trim(shapetype) == 'hicks-henne') then
    
    call HH_shape(x, modes, shape_function)
    
  else

    write(*,*)
    write(*,*) 'Shape function '//trim(shapetype)//' not recognized.'
    write(*,*)
    stop

  end if shape_switch

end subroutine create_shape

!=============================================================================80
!
! Populates shape function arrays for Hicks-Hene shape functions,
! number of elements in modes must be a multiple of 3.
!
!=============================================================================80
subroutine HH_shape(x, modes, shape_function)

  use vardef, only : initial_perturb, min_bump_width

  double precision, dimension(:), intent(in) :: x, modes
  double precision, dimension(:,:), intent(inout) :: shape_function

  integer :: npt, nmodes, i, j, counter1
  double precision :: power1, st, t1, t2, t1fact, t2fact, pi
  double precision :: chord, xle, xs

  npt = size(x,1)
  chord = x(npt) - x(1)
  xle = x(1)

  
  nmodes = size(modes,1)/3
  t1fact = initial_perturb/(1.d0 - 0.001d0)
  t2fact = initial_perturb/(10.d0 - min_bump_width)
  pi = acos(-1.d0)

  do i = 1, nmodes

    !     Extract strength, bump location, and width

    counter1 = 3*(i-1)
    st = modes(counter1+1)
    t1 = modes(counter1+2)/t1fact
    t2 = modes(counter1+3)/t2fact

    !     Check for problems with bump location and width parameters

    if (t1 <= 0.d0) t1 = 0.001d0
    if (t1 >= 1.d0) t1 = 0.999d0
    if (t2 <= 0.d0) t2 = 0.001d0

    !     Create shape function

    power1 = log10(0.5d0)/log10(t1)
    do j = 2, npt-1
      xs = (x(j)-xle)/chord
      shape_function(i,j) = st*sin(pi*xs**power1)**t2
    end do

  end do
end subroutine HH_shape
!=============================================================================80
!
! Populates shape function arrays for NACA shape functions
!
!=============================================================================80
subroutine NACA_shape(x, modes, shape_function)

  double precision, dimension(:), intent(in) :: x, modes
  double precision, dimension(:,:), intent(inout) :: shape_function

  integer :: npt, nmodes, i, j, counter1, counter2
  double precision :: power1, power2, dvscale
  double precision :: chord, xle, xs

  npt = size(x,1)
  chord = x(npt) - x(1)
  xle = x(1)

  nmodes = size(modes,1)

!   Create naca shape functions

  do j = 1, npt
    xs = (x(j)-xle)/chord
    shape_function(1,j) = sqrt(xs) - xs
  end do

  counter1 = 1
  counter2 = 1

  do i = 2, nmodes

!     Whole-powered shapes

    if (counter2 == 1) then

      power1 = dble(counter1)
      do j = 1, npt
        xs = (x(j)-xle)/chord
        shape_function(i,j) = xs**(power1)*(1.d0 - xs)
      end do
      counter2 = 2

!     Fractional-powered shapes

    else

      power1 = 1.d0/dble(counter1 + 2)
      power2 = 1.d0/dble(counter1 + 1)
      do j = 1, npt
        xs = (x(j)-xle)/chord
        shape_function(i,j) = xs**power1 - xs**power2
      end do
      counter2 = 1
      counter1 = counter1 + 1
       
    end if

  end do

!   Normalize shape functions

  do i = 1, nmodes
    dvscale = 1.d0/abs(maxval(shape_function(i,:)))
    shape_function(i,:) = shape_function(i,:)*dvscale
  end do

end subroutine NACA_shape
!=============================================================================80
!
! Creates an airfoil surface by perturbing an input "seed" airfoil
!
!=============================================================================80
subroutine create_airfoil(xt_seed, zt_seed, xb_seed, zb_seed, modest, modesb,  &
                          zt_new, zb_new, shapetype, symmetrical)

  double precision, dimension(:), intent(in) :: xt_seed, zt_seed, xb_seed,     &
                                                zb_seed
  double precision, dimension(:), intent(in) :: modest, modesb
  double precision, dimension(:), intent(inout) :: zt_new, zb_new
  character(*), intent(in) :: shapetype
  logical, intent(in) :: symmetrical

  if (trim(shapetype) == 'naca') then
    
    call NACA_airfoil(xt_seed, zt_seed, xb_seed, zb_seed, modest, modesb,      &
                          zt_new, zb_new, symmetrical)
  else
    
    call HH_airfoil(xt_seed, zt_seed, xb_seed, zb_seed, modest, modesb,        &
                          zt_new, zb_new, symmetrical)
  end if

end subroutine create_airfoil

!=============================================================================80
!
! Creates an airfoil surface by perturbing an input "seed" airfoil
! Using Hicks-Henne bump functions
!
!=============================================================================80
subroutine HH_airfoil(xt_seed, zt_seed, xb_seed, zb_seed, modest, modesb,      &
                          zt_new, zb_new, symmetrical)

  double precision, dimension(:), intent(in) :: xt_seed, zt_seed, xb_seed,     &
                                                zb_seed
  double precision, dimension(:), intent(in) :: modest, modesb
  double precision, dimension(:), intent(inout) :: zt_new, zb_new
  logical, intent(in) :: symmetrical

  integer :: i, nmodest, nmodesb, npointst, npointsb
  
  nmodest = size(modest,1)/3
  nmodesb = size(modesb,1)/3
  
  npointst = size(zt_seed,1)
  npointsb = size(zb_seed,1)

! Create shape functions for Hicks-Henne

  call create_shape_functions(xt_seed, xb_seed, modest, modesb, 'hicks-henne', &
                                first_time=.false.)

! Top surface

  zt_new = zt_seed
  do i = 1, nmodest
    zt_new = zt_new + top_shape_function(i,1:npointst)
  end do

! Bottom surface

  if (.not. symmetrical) then
    zb_new = zb_seed
    do i = 1, nmodesb
      zb_new = zb_new + bot_shape_function(i,1:npointsb)
    end do

! For symmetrical airfoils, just mirror the top surface

  else
    do i = 1, npointsb
      zb_new(i) = -zt_new(i)
    end do
  end if

end subroutine HH_airfoil

!=============================================================================80
!
! Creates an airfoil surface by perturbing an input "seed" airfoil
! Using NACA bump functions
!
!=============================================================================80
  subroutine NACA_airfoil(xt_seed, zt_seed, xb_seed, zb_seed, modest, modesb,  &
                          zt_new, zb_new, symmetrical)

  double precision, dimension(:), intent(in) :: xt_seed, zt_seed, xb_seed,     &
                                                zb_seed
  double precision, dimension(:), intent(in) :: modest, modesb
  double precision, dimension(:), intent(inout) :: zt_new, zb_new
  logical, intent(in) :: symmetrical

  integer :: i, nmodest, nmodesb, npointst, npointsb
  double precision :: strength

  nmodest = size(modest,1)
  nmodesb = size(modesb,1)

  npointst = size(zt_seed,1)
  npointsb = size(zb_seed,1)

! Top surface

  zt_new = zt_seed
  do i = 1, nmodest
    strength = modest(i)
    zt_new = zt_new + strength*top_shape_function(i,1:npointst)
  end do

! Bottom surface

  if (.not. symmetrical) then
    zb_new = zb_seed
    do i = 1, nmodesb
      strength = modesb(i)
      zb_new = zb_new + strength*bot_shape_function(i,1:npointsb)
    end do

! For symmetrical airfoils, just mirror the top surface

  else
    do i = 1, npointsb
      zb_new(i) = -zt_new(i)
    end do
  end if
  
  end subroutine NACA_airfoil
  
end module parametrization

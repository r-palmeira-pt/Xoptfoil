#pragma once

#include <QWidget>
#include <QMainWindow>

// Forward declarations

class SettingsWindow;

/******************************************************************************/
//
// Header for main window
//
/******************************************************************************/
class MainWindow : public QMainWindow
{
  private:

    // Widgets that may be placed in main window

    SettingsWindow *settingswindow;

  public:
 
    // Constructor

    MainWindow ( QWidget *parent = 0 );
};

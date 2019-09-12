function backupmanager() {
  try {
    toolbox.newDisplay("backupmanager");
  } catch (e) {
    print("initMenu::backupmanager exception @ " + e.lineNumber + ": " + e);
  }
}

function init() {
  var srMenu = mainwindow.findChild("menu.sales.reports");
  var tmpaction = srMenu.addAction(qsTr("Backup Manager"), mainwindow);
  tmpaction.objectName = "custom.backupmanager";
  //tmpaction.enabled = privileges.check("ViewBackupManager");
  tmpaction.triggered.connect(backupmanager);
}

init();
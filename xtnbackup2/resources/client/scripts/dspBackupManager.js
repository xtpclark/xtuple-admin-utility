mywindow.setWindowTitle(qsTr("Backup Manager"));
mywindow.setListLabel(qsTr("Backup Manager"));
mywindow.setReportName("BackupManagerNeedToMakeThis");
mywindow.setUseAltId(false);
mywindow.setMetaSQLOptions("backupmanager","detail");
mywindow.setQueryOnStartEnabled(true);
mywindow.setSearchVisible(true);
mywindow.setParameterWidgetVisible(true);

var _pw = mywindow.parameterWidget();

_pw.append(qsTr("Database"), 	"buhead_dbname", 		ParameterWidget.Text); 	
_pw.append(qsTr("Date"), 	"buhead_date", 		ParameterWidget.Date); 	

_pw.applyDefaultFilterSet();
var _list = mywindow.list();

_list.addColumn(qsTr("ID"), 			-1, Qt.AlignLeft, false, 	"buhead_id"); 			
_list.addColumn(qsTr("Host"), 		-1, Qt.AlignLeft, true, 	"buhead_host"); 	  
_list.addColumn(qsTr("Port"), 		-1, Qt.AlignLeft, true, 	"buhead_port"); 	  
_list.addColumn(qsTr("DBName"), 		-1, Qt.AlignLeft, true, 	"buhead_dbname"); 
_list.addColumn(qsTr("DBType"), 		-1, Qt.AlignLeft, true, 	"buhead_dbtype"); 		
_list.addColumn(qsTr("Username"), 	-1, Qt.AlignLeft, false, 	"buhead_username"); 	
_list.addColumn(qsTr("BackupDate"), 		-1, Qt.AlignLeft, true, 	"buhead_date"); 		
_list.addColumn(qsTr("Status"), 		-1, Qt.AlignLeft, true, 	"buhead_status"); 		
_list.addColumn(qsTr("Valid"), 		-1, Qt.AlignLeft, true, 	"buhead_valid"); 		
_list.addColumn(qsTr("LastEntry"), 		-1, Qt.AlignLeft, true, 	"buhead_lastgl"); 	  
_list.addColumn(qsTr("Size"), 		-1, Qt.AlignLeft, true, 	"buhead_dbsize"); 	  
_list.addColumn(qsTr("HasExt"), 		-1, Qt.AlignLeft, true, 	"buhead_hasext"); 		
_list.addColumn(qsTr("Filename"), 	-1, Qt.AlignLeft, true, 	"buhead_filename"); 	

_list.addColumn(qsTr("BuStart"), 	-1, Qt.AlignLeft, true, 	"buhead_bustart"); 	  
_list.addColumn(qsTr("BuStop"), 		-1, Qt.AlignLeft, true, 	"buhead_bustop"); 	  
_list.addColumn(qsTr("XferStart"), 	-1, Qt.AlignLeft, true, 	"buhead_xfstart"); 	  
_list.addColumn(qsTr("XferStop"), 		-1, Qt.AlignLeft, true, 	"buhead_xfstop"); 	  

_list.addColumn(qsTr("App"), 		-1, Qt.AlignLeft, true,     "buhead_appver");     
_list.addColumn(qsTr("Pkgs"), 		-1, Qt.AlignLeft, false,     "buhead_pkgs");       
_list.addColumn(qsTr("Exts"), 		-1, Qt.AlignLeft, false,     "buhead_exts");       
_list.addColumn(qsTr("Edition"), 	-1, Qt.AlignLeft, true,     "buhead_edition");    
_list.addColumn(qsTr("StorURL"), 	-1, Qt.AlignLeft, true,     "buhead_storurl");    
_list.addColumn(qsTr("RegKey"), 		-1, Qt.AlignLeft, false,     "buhead_regkey");     
_list.addColumn(qsTr("Remit-To"), 	-1, Qt.AlignLeft, true,     "buhead_remitto");    
_list.addColumn(qsTr("PgVersion"), 	-1, Qt.AlignLeft, false,   	"buhead_pgversion");  


_list["populateMenu(QMenu *, XTreeWidgetItem *)"].connect(sPopulateMenu);

function sPopulateMenu(pMenu, pItem)
{
  QMessageBox.information(_list, qsTr("Right Click"),
                          qsTr("Right button clicked on %1: %2 Host: %3")
                              .arg(pItem.id())
                              .arg(pItem.text("buhead_dbname"))
                              .arg(pItem.text("buhead_host"))
  );
  // the real function contents look a lot like an initmenu script
  // add the actions to pMenu instead of whatever menu object initmenu grabbed
}
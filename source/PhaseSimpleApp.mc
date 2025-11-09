import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PhaseSimpleApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    // [修正] 関数の定義から戻り値の型指定 (as Array...) を削除
    function getInitialView() {
        return [ new PhaseSimpleView() ];
    }
}
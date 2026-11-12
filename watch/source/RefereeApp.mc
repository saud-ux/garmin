import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Global singleton for the active match. Created when a match starts.
var gMatch = null;
// Global Firebase sync helper.
var gSync = null;
// Global reference to the main match screen (for toasts from pushed views).
var gMainView = null;

class RefereeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        gSync = new Sync();
    }

    function onStop(state as Dictionary?) as Void {
        if (gMatch != null) {
            gMatch.stopTimer();
        }
    }

    // First screen: setup / kickoff selection.
    function getInitialView() {
        var view = new SetupView();
        return [ view, new SetupDelegate(view) ];
    }
}

function getApp() as RefereeApp {
    return Application.getApp() as RefereeApp;
}

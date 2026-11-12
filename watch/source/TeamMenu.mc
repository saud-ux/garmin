import Toybox.Lang;
import Toybox.WatchUi;

// Team event menu (goal / yellow / red), opened by swipe up/down.
function buildTeamMenu(match, team) {
    var name = match.teamName(team);
    var menu = new WatchUi.Menu2({ :title => name });
    menu.addItem(new WatchUi.MenuItem("هدف", null, "goal", null));
    menu.addItem(new WatchUi.MenuItem("بطاقة صفراء", null, "yellow", null));
    menu.addItem(new WatchUi.MenuItem("بطاقة حمراء", null, "red", null));
    return menu;
}

class TeamMenuDelegate extends WatchUi.Menu2InputDelegate {
    var team;

    function initialize(t) {
        Menu2InputDelegate.initialize();
        team = t;
    }

    function onSelect(item) {
        var kind = item.getId();            // "goal" | "yellow" | "red"
        WatchUi.popView(WatchUi.SLIDE_DOWN); // close menu -> back to main
        var np = new NumberPad("player", kind, team);
        WatchUi.pushView(np, new NumberPadDelegate(np), WatchUi.SLIDE_UP);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

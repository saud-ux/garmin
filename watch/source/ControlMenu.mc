import Toybox.Lang;
import Toybox.WatchUi;

// Bottom-button control menu. Content depends on match phase.
function buildControlMenu(match) {
    var menu = new WatchUi.Menu2({ :title => "التحكم" });
    if (match.phase.equals("1st")) {
        menu.addItem(new WatchUi.MenuItem("إنهاء الشوط الأول", null, "endFirst", null));
    } else if (match.phase.equals("half")) {
        menu.addItem(new WatchUi.MenuItem("بدء الشوط الثاني", null, "startSecond", null));
    } else if (match.phase.equals("2nd")) {
        menu.addItem(new WatchUi.MenuItem("إنهاء المباراة", null, "endMatch", null));
    }
    menu.addItem(new WatchUi.MenuItem("تراجع عن آخر حدث", null, "undo", null));
    return menu;
}

class ControlMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        var m = gMatch;
        if (m == null) { WatchUi.popView(WatchUi.SLIDE_DOWN); return; }

        if (id.equals("endFirst")) {
            m.endFirstHalf();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id.equals("startSecond")) {
            m.startSecondHalf();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id.equals("endMatch")) {
            m.endMatch();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id.equals("undo")) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);   // close menu -> main
            var dialog = new WatchUi.Confirmation("تراجع عن آخر حدث؟");
            WatchUi.pushView(dialog, new UndoConfirmDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class UndoConfirmDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES && gMatch != null) {
            gMatch.undoLast();
            if (gMainView != null) {
                gMainView.showToast("تم التراجع");
            }
        }
        return true;
    }
}

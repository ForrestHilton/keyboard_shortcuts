library keyboard_shortcuts;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:visibility_detector/visibility_detector.dart';

Widget homeWidget;
List<KeyBoardShortcuts> keyBoardShortcuts = [];
Widget customGlobal;
String customTitle;
IconData customIcon;
bool helperIsOpen = false;

enum BasicShortCuts {
  creation,
  previousPage,
  nextPage,
  save,
}

void initShortCuts(Widget homePage, {Widget helpGlobal, String helpTitle, IconData helpIcon}) {
  homeWidget = homePage;
  customGlobal = helpGlobal;
  customTitle = helpTitle;
  customIcon = helpIcon;
}

bool isPressed(Set<LogicalKeyboardKey> keysPressed, Set<LogicalKeyboardKey> keysToPress) =>
    keysPressed.containsAll(keysToPress) && keysPressed.length == keysToPress.length;

class KeyBoardShortcuts extends StatefulWidget {
  final Widget child;

  /// You can use shortCut function with BasicShortCuts to avoid write data by yourself
  final Set<LogicalKeyboardKey> keysToPress;

  /// Function when keys are pressed
  final VoidCallback onKeysPressed;

  /// Label who will be displayed in helper
  final String helpLabel;

  /// Activate when this widget is the first of the page
  final bool globalShortcuts;

  KeyBoardShortcuts({this.keysToPress, this.onKeysPressed, this.helpLabel, this.globalShortcuts = false, @required this.child, Key key})
      : super(key: key);

  @override
  _KeyBoardShortcuts createState() => _KeyBoardShortcuts();
}

class _KeyBoardShortcuts extends State<KeyBoardShortcuts> {
  FocusScopeNode focusScopeNode;
  ScrollController _controller = ScrollController();
  bool controllerIsReady = false;
  bool listening = false;

  @override
  void initState() {
    _controller.addListener(() {
      if (_controller.hasClients) setState(() => controllerIsReady = true);
    });
    _attachKeyboardIfDetached();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _detachKeyboardIfAttached();
  }

  void _attachKeyboardIfDetached() {
    if (listening) return;
    keyBoardShortcuts.add(this.widget);
    RawKeyboard.instance.addListener(listener);
    listening = true;
  }

  void _detachKeyboardIfAttached() {
    if (!listening) return;
    RawKeyboard.instance.removeListener(listener);
    listening = false;
    keyBoardShortcuts.remove(this.widget);
  }

  void listener(RawKeyEvent v) async {
    if (!mounted) return;

    Set<LogicalKeyboardKey> keysPressed = RawKeyboard.instance.keysPressed;
    if (v.runtimeType == RawKeyDownEvent) {
      // when user type keysToPress
      if (widget.keysToPress != null && widget.onKeysPressed != null && isPressed(keysPressed, widget.keysToPress)) {
        widget.onKeysPressed();
      }

      // when user request help menu
      else if (isPressed(keysPressed, {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyH})) {
        List<Widget> activeHelp = [];

        keyBoardShortcuts.forEach((element) {
          Widget elementWidget = helpWidget(element);
          if (elementWidget != null) activeHelp.add(elementWidget);
        }); // get all custom shortcuts

        bool showGlobalShort = keyBoardShortcuts.any((element) => element.globalShortcuts);

        if (!helperIsOpen && (activeHelp.isNotEmpty || showGlobalShort)) {
          helperIsOpen = true;

          await showDialog<void>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              key: UniqueKey(),
              title: Text(customTitle ?? 'Keyboard Shortcuts'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    if (activeHelp.isNotEmpty)
                      ListBody(
                        children: [
                          for (final i in activeHelp) i,
                          Divider(),
                        ],
                      ),
                    if (showGlobalShort)
                      customGlobal != null
                          ? customGlobal
                          : ListBody(
                              children: [
                                ListTile(
                                  leading: Icon(Icons.home),
                                  title: Text("Go on Home page"),
                                  subtitle: Text(LogicalKeyboardKey.home.debugName),
                                ),
                                ListTile(
                                  leading: Icon(Icons.subdirectory_arrow_left),
                                  title: Text("Go on last page"),
                                  subtitle: Text(LogicalKeyboardKey.escape.debugName),
                                ),
                                ListTile(
                                  leading: Icon(Icons.keyboard_arrow_up),
                                  title: Text("Scroll to top"),
                                  subtitle: Text(LogicalKeyboardKey.pageUp.debugName),
                                ),
                                ListTile(
                                  leading: Icon(Icons.keyboard_arrow_down),
                                  title: Text("Scroll to bottom"),
                                  subtitle: Text(LogicalKeyboardKey.pageDown.debugName),
                                ),
                              ],
                            ),
                  ],
                ),
              ),
            ),
          ).then((value) => helperIsOpen = false);
        }
      } else if (widget.globalShortcuts && keysPressed.length == 1) {
        if (homeWidget != null && isPressed(keysPressed, {LogicalKeyboardKey.home})) {
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => homeWidget), (_) => false);
        } else if (isPressed(keysPressed, {LogicalKeyboardKey.escape})) {
          Navigator.maybePop(context);
        } else if (controllerIsReady && keysPressed.containsAll({LogicalKeyboardKey.pageDown}) ||
            keysPressed.first.keyId == 0x10700000022) {
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            duration: new Duration(milliseconds: 50),
            curve: Curves.easeOut,
          );
        } else if (controllerIsReady && keysPressed.containsAll({LogicalKeyboardKey.pageUp}) || keysPressed.first.keyId == 0x10700000021) {
          _controller.animateTo(
            _controller.position.minScrollExtent,
            duration: new Duration(milliseconds: 50),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: UniqueKey(),
      child: PrimaryScrollController(controller: _controller, child: widget.child),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction == 1)
          _attachKeyboardIfDetached();
        else
          _detachKeyboardIfAttached();
      },
    );
  }
}

Widget helpWidget(KeyBoardShortcuts widget) {
  String text = "";
  if (widget.keysToPress != null) {
    for (final i in widget.keysToPress) text += i.debugName + " + ";
    text = text.substring(0, text.lastIndexOf(" + "));
  }
  if (widget.helpLabel != null && text != "")
    return ListTile(
      leading: Icon(customIcon ?? Icons.settings),
      title: Text(widget.helpLabel),
      subtitle: Text(text),
    );
  return null;
}

Set<LogicalKeyboardKey> shortCut(BasicShortCuts basicShortCuts) {
  switch (basicShortCuts) {
    case BasicShortCuts.creation:
      return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyN};
    case BasicShortCuts.previousPage:
      return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowLeft};
    case BasicShortCuts.nextPage:
      return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowRight};
    case BasicShortCuts.save:
      return {LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyS};
    default:
      return {};
  }
}

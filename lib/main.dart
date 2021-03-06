import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';   
import 'package:flutter/cupertino.dart';    
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async'; 
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; 
import 'package:firebase_database/ui/firebase_animated_list.dart';

void main() {
  runApp(new FriendlychatApp());
}

class FriendlychatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: "Chatty",
      theme: defaultTargetPlatform == TargetPlatform.iOS         
        ? kIOSTheme                                              
        : kDefaultTheme,
      home: new ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {                     
  @override                                                        
  State createState() => new ChatScreenState();                    
} 

// Add the ChatScreenState class definition in main.dart.

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _textController = new TextEditingController();
  final reference = FirebaseDatabase.instance.reference().child('messages'); 
  bool _isComposing = false;                 
  @override                                                        
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
          title: new Text("Chatty"),
          elevation:
              Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0),
            body: new Column(children: <Widget>[ 
                    new Flexible(
                      child: new FirebaseAnimatedList(                            //new
                          query: reference,                                       //new
                          sort: (a, b) => b.key.compareTo(a.key),                 //new
                          padding: new EdgeInsets.all(8.0),                       //new
                          reverse: true,                                          //new
                          itemBuilder: (_, DataSnapshot snapshot, Animation<double> animation) { //new
                            return new ChatMessage(                               //new
                              snapshot: snapshot,                                 //new
                              animation: animation                                //new
                            );                                                    //new
                          },                                                      //new
                        ),                                                        //new
                      ),

                // child: new ListView.builder(
                //   padding: new EdgeInsets.all(8.0),
                //   reverse: true,
                //   itemBuilder: (_, int index) => _messages[index],
                //   itemCount: _messages.length,
                // ),
              ),
              new Divider(height: 1.0),
              new Container(
                decoration: new BoxDecoration(color: Theme.of(context).cardColor),
                child: _buildTextComposer(),
              ),
            ],
          ),
          decoration: Theme.of(context).platform == TargetPlatform.iOS 
              ? new BoxDecoration(                                     
                  border: new Border(                                  
                    top: new BorderSide(color: Colors.grey[200]),      
                  ),                                                   
                )                                                      
              : null),                                                 
    );
  }
  @override
  void dispose() {                                                   
    for (ChatMessage message in _messages)                           
      message.animationController.dispose();                         
    super.dispose();                                                 
  } 
  Future<Null> _ensureLoggedIn() async {
    GoogleSignInAccount user = googleSignIn.currentUser;
    if (user == null)
      user = await googleSignIn.signInSilently();
    if (user == null) {
      await googleSignIn.signIn();
      analytics.logLogin();
    }
    if (await auth.currentUser() == null) {
      GoogleSignInAuthentication credentials =
      await googleSignIn.currentUser.authentication;
      await auth.signInWithGoogle(
        idToken: credentials.idToken,
        accessToken: credentials.accessToken,
      );
    }
  }    
  Widget _buildTextComposer() {
    return new IconTheme(
      data: new IconThemeData(color: Theme.of(context).accentColor),
      child: new Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: new Row(
          children: <Widget>[
            new Flexible(
              child: new TextField(
                controller: _textController,
                onChanged: (String text) {          
                  setState(() {                     
                    _isComposing = text.length > 0; 
                  });                               
                },                                  
                onSubmitted: _handleSubmitted,
                decoration:
                    new InputDecoration.collapsed(hintText: "Send a message"),
              ),
            ),
            new Container(
              margin: new EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.iOS ?  
              new CupertinoButton(                                       
                child: new Text("Send"),                                 
                onPressed: _isComposing                                  
                    ? () =>  _handleSubmitted(_textController.text)      
                    : null,) :
              new IconButton(
                icon: new Icon(Icons.send),
                onPressed: _isComposing
                    ? () => _handleSubmitted(_textController.text)    
                    : null,                                           
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<Null> _handleSubmitted(String text) async {
    _textController.clear();
    setState(() {                                                    
      _isComposing = false;                                          
    });
    await _ensureLoggedIn();                                       
    _sendMessage(text: text);                                                              
    ChatMessage message = new ChatMessage(
      text: text,
      animationController: new AnimationController(
        duration: new Duration(milliseconds: 700),
        vsync: this,
      ),
    );
    setState(() {
      _messages.insert(0, message);
    });
    message.animationController.forward();
  }
  void _sendMessage({ String text }) {
    reference.push().set({
      'text': text,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl,
    });
    analytics.logEvent(name: 'send_message');                 
  }
}

class ChatMessage extends StatelessWidget {
  ChatMessage({this.text, this.animationController});
  final String text;
  final AnimationController animationController;

  Widget build(BuildContext context) {
    return new SizeTransition(
      sizeFactor: new CurvedAnimation(
          parent: animationController, curve: Curves.easeOut),
      axisAlignment: 0.0,
      child: new Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Container(
                margin: const EdgeInsets.only(right: 16.0),
                child: new CircleAvatar(
                    backgroundImage:
                        new NetworkImage(googleSignIn.currentUser.photoUrl)
                    )
                ),
            new Expanded(
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Text(googleSignIn.currentUser.displayName,                 
                      style: Theme.of(context).textTheme.subhead),
                  new Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: new Text(text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),                                                           
    );
  }
}

const String _name = "Your Name";

final ThemeData kIOSTheme = new ThemeData(
  primarySwatch: Colors.orange,
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light,
);

final ThemeData kDefaultTheme = new ThemeData(
  primarySwatch: Colors.purple,
  accentColor: Colors.orangeAccent[400],
);

final googleSignIn = new GoogleSignIn();  
final analytics = new FirebaseAnalytics();
final auth = FirebaseAuth.instance;

class ChatMessage extends StatelessWidget {
   ChatMessage({this.snapshot, this.animation});              // modified
   final DataSnapshot snapshot;                               // modified
   final Animation animation;   
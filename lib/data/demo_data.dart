// Placeholder data so the UI can be reviewed before the backend is wired.
// Replaced by Supabase queries (chat_list_view, messages, calls) later.
import 'package:material_ui/material_ui.dart';

enum ChatFilter { all, unread, groups, archived }

enum ChatMarker { none, activeStatus, seenStatus }

class DemoChat {
  const DemoChat({
    required this.id,
    required this.name,
    required this.preview,
    required this.time,
    this.unread = 0,
    this.isGroup = false,
    this.isOnline = false,
    this.isArchived = false,
    this.previewIsPhoto = false,
    this.marker = ChatMarker.none,
    this.avatarColor,
    this.phone = '',
    this.about = 'Hey there! I am using SchatzApp.',
    this.members = const [],
    this.mediaCount = 0,
    this.username = '',
    this.links = const [],
    this.groupsInCommon = 0,
    this.mutualContacts = 0,
  });

  final String id;
  final String name;
  final String preview;
  final String time;
  final int unread;
  final bool isGroup;
  final bool isOnline;
  final bool isArchived;
  final bool previewIsPhoto;
  final ChatMarker marker;

  /// Null means no photo: show the default person or group icon.
  final Color? avatarColor;

  final String phone;

  /// About text for people, description for groups.
  final String about;

  /// Group member names (groups only).
  final List<String> members;

  final int mediaCount;

  final String username;

  /// Links shared in this chat: (title, url).
  final List<(String, String)> links;

  final int groupsInCommon;
  final int mutualContacts;
}

enum MessageKind { text, image }

class DemoMessage {
  const DemoMessage({
    required this.text,
    required this.time,
    required this.isMine,
    this.kind = MessageKind.text,
    this.isRead = true,
  });

  final String text;
  final String time;
  final bool isMine;
  final MessageKind kind;
  final bool isRead;
}

const demoChats = <DemoChat>[
  DemoChat(
    id: 'kesta',
    name: 'Mr Kesta Wealth',
    preview: 'Hi smally',
    time: '2:36 PM',
    unread: 1,
    isOnline: true,
    avatarColor: Color(0xFF8A6A55),
    phone: '+234 903 287 7996',
    about: 'God has been faithful to me, and I can\'t lie at all',
    mediaCount: 5,
    username: 'kestawealth',
    links: [
      ('YouTube', 'https://www.youtube.com'),
      ('Facebook', 'https://www.facebook.com'),
      ('WhatsApp', 'https://whatsapp.com'),
    ],
    groupsInCommon: 8,
    mutualContacts: 6,
  ),
  DemoChat(
    id: 'best',
    name: 'Best Group',
    preview: 'calm down',
    time: 'Tuesday',
    isGroup: true,
    avatarColor: Color(0xFFB0413E),
    about: 'Friends and good vibes only.',
    members: ['Mr Kesta Wealth', 'My Airtel Number', 'Temidayo WAM'],
    mediaCount: 12,
    links: [('SchatzApp', 'https://schatzapp.com')],
  ),
  DemoChat(
    id: 'sdff',
    name: 'sdff',
    preview: '',
    time: '11/12/26',
    isGroup: true,
    about: '',
    members: ['Mr Kesta Wealth'],
  ),
  DemoChat(
    id: 'kskaka',
    name: 'kskaka',
    preview: '',
    time: '11/12/26',
    isGroup: true,
    about: '',
    members: ['Temidayo WAM'],
  ),
  DemoChat(
    id: 'airtel',
    name: 'My Airtel Number',
    preview: 'Guy',
    time: '11/12/26',
    marker: ChatMarker.activeStatus,
    avatarColor: Color(0xFF6B6F78),
    phone: '+234 901 234 5678',
  ),
  DemoChat(
    id: 'wam',
    name: 'Temidayo WAM',
    preview: 'Photo',
    time: '11/09/26',
    previewIsPhoto: true,
    marker: ChatMarker.seenStatus,
    avatarColor: Color(0xFF3F7D4E),
    phone: '+234 803 555 0101',
    mediaCount: 3,
  ),
  DemoChat(
    id: 'archived',
    name: 'Old Project Group',
    preview: 'See you all next week',
    time: '10/30/26',
    isGroup: true,
    isArchived: true,
    members: ['Mr Kesta Wealth', 'Temidayo WAM'],
  ),
];

const demoMessages = <String, List<DemoMessage>>{
  'kesta': [
    DemoMessage(text: 'Hi smally', time: '2:36 PM', isMine: false),
    DemoMessage(text: 'Hello, how are you?', time: '2:40 PM', isMine: true),
    DemoMessage(
      text: "I'm good, thanks. Are you free for a quick chat?",
      time: '2:42 PM',
      isMine: false,
    ),
    DemoMessage(text: "Yes, sure. What's up?", time: '2:45 PM', isMine: true),
    DemoMessage(
      text: '',
      time: '2:47 PM',
      isMine: false,
      kind: MessageKind.image,
    ),
    DemoMessage(text: "That's beautiful.", time: '2:50 PM', isMine: true),
  ],
  'best': [
    DemoMessage(
      text: 'Who is coming on Saturday?',
      time: '9:10 AM',
      isMine: false,
    ),
    DemoMessage(text: 'I will be there', time: '9:12 AM', isMine: true),
    DemoMessage(text: 'calm down', time: '9:15 AM', isMine: false),
  ],
  'airtel': [DemoMessage(text: 'Guy', time: '4:02 PM', isMine: false)],
  'wam': [
    DemoMessage(
      text: '',
      time: '6:20 PM',
      isMine: false,
      kind: MessageKind.image,
    ),
  ],
  'archived': [
    DemoMessage(text: 'See you all next week', time: '1:00 PM', isMine: false),
  ],
};

// ---------------------------------------------------------------------------
// Calls
// ---------------------------------------------------------------------------

enum CallFilter { all, missed, incoming, outgoing }

enum CallDirection { incoming, outgoing, declined, cancelled, missed }

class DemoCall {
  const DemoCall({
    required this.id,
    required this.name,
    required this.direction,
    required this.date,
    required this.time,
    this.duration,
    this.isVideo = true,
    this.isOnline = true,
    this.avatarColor = const Color(0xFF8A6A55),
  });

  final String id;
  final String name;
  final CallDirection direction;
  final String date;
  final String time;
  final String? duration;
  final bool isVideo;
  final bool isOnline;
  final Color avatarColor;

  String get label => switch (direction) {
    CallDirection.incoming => 'Incoming',
    CallDirection.outgoing => 'Outgoing',
    CallDirection.declined => 'Declined',
    CallDirection.cancelled => 'Cancelled',
    CallDirection.missed => 'Missed',
  };

  String get typeLabel => '$label Call';
}

const demoCalls = <DemoCall>[
  DemoCall(
    id: 'c1',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.incoming,
    date: '21 Nov',
    time: '7:03 PM',
    duration: '3m 21s',
  ),
  DemoCall(
    id: 'c2',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.outgoing,
    date: '21 Nov',
    time: '7:01 PM',
    duration: '26s',
  ),
  DemoCall(
    id: 'c3',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.outgoing,
    date: '21 Nov',
    time: '7:00 PM',
    duration: '17s',
  ),
  DemoCall(
    id: 'c4',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.declined,
    date: '21 Nov',
    time: '7:00 PM',
  ),
  DemoCall(
    id: 'c5',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.incoming,
    date: '21 Nov',
    time: '6:58 PM',
    duration: '52s',
  ),
  DemoCall(
    id: 'c6',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.incoming,
    date: '21 Nov',
    time: '6:20 PM',
    duration: '1m 27s',
  ),
  DemoCall(
    id: 'c7',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.incoming,
    date: '21 Nov',
    time: '3:12 PM',
    duration: '1m 19s',
  ),
  DemoCall(
    id: 'c8',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.cancelled,
    date: '21 Nov',
    time: '3:11 PM',
  ),
  DemoCall(
    id: 'c9',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.missed,
    date: '20 Nov',
    time: '6:21 PM',
    isVideo: false,
  ),
  DemoCall(
    id: 'c10',
    name: 'Mr Kesta Wealth',
    direction: CallDirection.missed,
    date: '20 Nov',
    time: '6:20 PM',
    isVideo: false,
  ),
];

const demoCurrentUserName = 'Chloe Bites';

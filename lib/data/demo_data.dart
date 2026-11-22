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

// ---------------------------------------------------------------------------
// Wallet
// ---------------------------------------------------------------------------

const demoWalletBalance = 'SFZ 64,300';
const demoWalletLocal = '= NGN 941,846';

enum TxKind { transfer, giftcard }

class DemoTransaction {
  const DemoTransaction({
    required this.id,
    required this.title,
    required this.status,
    required this.date,
    required this.amount,
    required this.kind,
    this.counterparty = 'Mr Kesta Wealth',
  });

  final String id;
  final String title;
  final String status;
  final String date;
  final String amount;
  final TxKind kind;
  final String counterparty;
}

const demoTransactions = <DemoTransaction>[
  DemoTransaction(
    id: 't1',
    title: 'Incoming Transfer',
    status: 'success',
    date: '18 Nov 2026 · 6:57 AM',
    amount: '+\$50.00',
    kind: TxKind.transfer,
  ),
  DemoTransaction(
    id: 't2',
    title: 'Incoming Transfer',
    status: 'success',
    date: '18 Nov 2026 · 6:56 AM',
    amount: '+\$50.00',
    kind: TxKind.transfer,
  ),
  DemoTransaction(
    id: 't3',
    title: 'Incoming Transfer',
    status: 'success',
    date: '15 Nov 2026 · 3:59 PM',
    amount: '+\$50.00',
    kind: TxKind.transfer,
  ),
  DemoTransaction(
    id: 't4',
    title: 'Giftcard_received',
    status: 'success',
    date: '10 Nov 2026 · 8:14 PM',
    amount: '+SCHATZ 1,000.00',
    kind: TxKind.giftcard,
  ),
];

// ---------------------------------------------------------------------------
// Private chats, contacts, chat themes, countries
// ---------------------------------------------------------------------------

/// Locked (Private) chats. Never shown in the normal list or search; only
/// inside the Private Chats view after the app password gate.
const demoPrivateChats = <DemoChat>[
  DemoChat(
    id: 'p1',
    name: 'Ada Okafor',
    preview: 'See you tonight',
    time: '9:41 PM',
    unread: 2,
    avatarColor: Color(0xFFB4508A),
    phone: '+234 802 111 2233',
  ),
  DemoChat(
    id: 'p2',
    name: 'Family Vault',
    preview: 'Documents uploaded',
    time: 'Monday',
    isGroup: true,
    members: ['Mr Kesta Wealth', 'Temidayo WAM'],
  ),
];

class DemoContact {
  const DemoContact(this.name, this.phone, [this.color]);

  final String name;
  final String phone;
  final Color? color;
}

const demoContacts = <DemoContact>[
  DemoContact('Ada Okafor', '+234 802 111 2233', Color(0xFFB4508A)),
  DemoContact('Bayo Adeniyi', '+234 805 444 9090', Color(0xFF3E6FB0)),
  DemoContact('Chloe Bites', '+234 701 000 1234'),
  DemoContact('Mr Kesta Wealth', '+234 903 287 7996', Color(0xFF8A6A55)),
  DemoContact('My Airtel Number', '+234 901 234 5678', Color(0xFF6B6F78)),
  DemoContact('Ngozi Eze', '+234 809 777 1212', Color(0xFF2F8F83)),
  DemoContact('Temidayo WAM', '+234 803 555 0101', Color(0xFF3F7D4E)),
  DemoContact('Tunde Bello', '+234 816 333 4545'),
];

/// Chat themes, same five as the mobile app (theme1 to theme5).
class ChatThemeDef {
  const ChatThemeDef({
    required this.key,
    required this.sender,
    required this.receiver,
    required this.background,
  });

  final String key;
  final Color sender;
  final Color receiver;
  final Color background;

  String get preview => 'assets/images/themes/$key.jpg';
}

const chatThemes = <ChatThemeDef>[
  ChatThemeDef(
    key: 'theme1',
    sender: Color(0xFFED50E4),
    receiver: Color(0xFFF1F5F9),
    background: Color(0xFFFCE9F6),
  ),
  ChatThemeDef(
    key: 'theme2',
    sender: Color(0xFFED50E4),
    receiver: Color(0xFFF1F5F9),
    background: Color(0xFFFDEFF8),
  ),
  ChatThemeDef(
    key: 'theme3',
    sender: Color(0xFF3B82F6),
    receiver: Color(0xFFFFFFFF),
    background: Color(0xFFEBF1FE),
  ),
  ChatThemeDef(
    key: 'theme4',
    sender: Color(0xFF0E8BAB),
    receiver: Color(0xFFE2E8F0),
    background: Color(0xFFE9F4F7),
  ),
  ChatThemeDef(
    key: 'theme5',
    sender: Color(0xFF935CCC),
    receiver: Color(0xFFF0F0F0),
    background: Color(0xFFFAF4EA),
  ),
];

class DemoCountry {
  const DemoCountry(this.name, this.code, this.dial);

  final String name;

  /// ISO 3166 alpha-2, lower case (used for the flag image).
  final String code;
  final String dial;
}

const demoCountries = <DemoCountry>[
  DemoCountry('Nigeria', 'ng', '+234'),
  DemoCountry('Ghana', 'gh', '+233'),
  DemoCountry('Kenya', 'ke', '+254'),
  DemoCountry('South Africa', 'za', '+27'),
  DemoCountry('United Kingdom', 'gb', '+44'),
  DemoCountry('United States', 'us', '+1'),
  DemoCountry('Canada', 'ca', '+1'),
  DemoCountry('Germany', 'de', '+49'),
  DemoCountry('France', 'fr', '+33'),
  DemoCountry('United Arab Emirates', 'ae', '+971'),
];

// ---------------------------------------------------------------------------
// Stories
// ---------------------------------------------------------------------------

enum StoryKind { photo, text }

class StoryItem {
  const StoryItem.photo({this.caption = ''})
    : kind = StoryKind.photo,
      text = '',
      background = const Color(0xFF000000);

  const StoryItem.text(this.text, this.background)
    : kind = StoryKind.text,
      caption = '';

  final StoryKind kind;
  final String text;
  final String caption;
  final Color background;
}

class DemoStory {
  const DemoStory({
    required this.name,
    required this.time,
    required this.items,
    this.color,
    this.viewed = false,
  });

  final String name;
  final String time;
  final List<StoryItem> items;
  final Color? color;
  final bool viewed;
}

const demoStories = <DemoStory>[
  DemoStory(
    name: 'Mr Kesta Wealth',
    time: '1h ago',
    color: Color(0xFF8A6A55),
    items: [
      StoryItem.text('hey', Color(0xFF0A84FF)),
      StoryItem.photo(caption: 'Evening by the lake'),
      StoryItem.text('Grateful for today', Color(0xFF7A2BE8)),
    ],
  ),
  DemoStory(
    name: 'Temidayo WAM',
    time: '3h ago',
    color: Color(0xFF3F7D4E),
    items: [
      StoryItem.text('Building something big. Stay tuned!', Color(0xFF0E8BAB)),
    ],
  ),
  DemoStory(
    name: 'Ada Okafor',
    time: 'Yesterday',
    color: Color(0xFFB4508A),
    viewed: true,
    items: [StoryItem.photo(caption: 'Weekend vibes')],
  ),
];

// ---------------------------------------------------------------------------
// For You posts (one post can hold several photos/videos: a carousel)
// ---------------------------------------------------------------------------

class FeedMedia {
  const FeedMedia.image(this.url) : isVideo = false, thumb = url;
  const FeedMedia.video(this.url, {required this.thumb}) : isVideo = true;

  /// Asset path for the demo; a storage URL in the backend phase.
  final String url;
  final bool isVideo;

  /// Still image used for the blurred background (video thumbnail).
  final String thumb;
}

class DemoPost {
  const DemoPost.media(this.author, this.media)
    : text = null,
      background = const Color(0xFF000000);
  const DemoPost.text(this.author, this.text, this.background)
    : media = const [];

  final DemoStory author;
  final List<FeedMedia> media;
  final String? text;
  final Color background;
}

final demoPosts = <DemoPost>[
  DemoPost.media(demoStories[0], const [
    FeedMedia.image('assets/demo/beach_portrait.jpg'),
    FeedMedia.video(
      'assets/demo/demo_portrait.mp4',
      thumb: 'assets/demo/demo_portrait_thumb.jpg',
    ),
    FeedMedia.image('assets/demo/desert_landscape.jpg'),
  ]),
  DemoPost.text(demoStories[0], 'hey', const Color(0xFF0A84FF)),
  DemoPost.media(demoStories[1], const [
    FeedMedia.video(
      'assets/demo/demo_portrait.mp4',
      thumb: 'assets/demo/demo_portrait_thumb.jpg',
    ),
  ]),
  DemoPost.media(demoStories[2], const [
    FeedMedia.image('assets/demo/desert_portrait.jpg'),
  ]),
  DemoPost.text(
    demoStories[1],
    'Building something big. Stay tuned!',
    const Color(0xFF0E8BAB),
  ),
];

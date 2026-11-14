import 'package:flutter/material.dart';

/// One emoji with the words people search for it by.
typedef EmojiEntry = ({String emoji, String keywords});

typedef EmojiCategory = ({String name, IconData icon, List<EmojiEntry> emojis});

List<EmojiEntry> _parse(String data) => [
  for (final line in data.trim().split('\n'))
    if (line.trim().isNotEmpty)
      (
        emoji: line.trim().split(' ').first,
        keywords: line.trim().substring(line.trim().indexOf(' ') + 1),
      ),
];

/// The picker's categories, in the order a messaging app shows them.
final List<EmojiCategory> kEmojiCategories = [
  (
    name: 'Smileys',
    icon: Icons.emoji_emotions_outlined,
    emojis: _parse('''
😀 grinning smile happy
😃 smiley happy joy
😄 smile happy laugh
😁 grin beaming
😆 laughing squint
😅 sweat smile relief
🤣 rolling floor laughing rofl
😂 joy tears laughing lol
🙂 slightly smiling
🙃 upside down silly
😉 wink
😊 blush smiling happy
😇 innocent halo angel
🥰 love hearts smiling
😍 heart eyes love
🤩 star struck wow
😘 kiss blowing
😗 kissing
😚 kissing closed eyes
😙 kissing smiling eyes
🥲 smiling tear grateful
😋 yum delicious
😛 tongue
😜 winking tongue crazy
🤪 zany crazy
😝 squinting tongue
🤑 money mouth rich
🤗 hug hugging
🤭 hand over mouth oops
🫢 gasp surprise
🤫 shush quiet secret
🤔 thinking hmm
🫡 salute respect
🤐 zipper mouth secret
🤨 raised eyebrow skeptical
😐 neutral meh
😑 expressionless
😶 no mouth speechless
🫥 dotted line invisible
😏 smirk
😒 unamused
🙄 eye roll
😬 grimace awkward
😮‍💨 exhale relief sigh
🤥 lying
😌 relieved calm
😔 pensive sad
😪 sleepy
🤤 drooling
😴 sleeping zzz tired
😷 mask sick
🤒 thermometer sick ill
🤕 bandage hurt
🤢 nauseated sick
🤮 vomiting
🥵 hot sweating
🥶 cold freezing
🥴 woozy dizzy
😵 dizzy
🤯 mind blown exploding head
🤠 cowboy
🥳 party celebrate birthday
🥸 disguise
😎 cool sunglasses
🤓 nerd geek
🧐 monocle curious
😕 confused
🫤 diagonal mouth unsure
😟 worried
🙁 frowning sad
😮 open mouth surprised
😯 hushed
😲 astonished shocked
😳 flushed embarrassed
🥺 pleading puppy eyes please
🥹 holding back tears touched
😦 frowning open mouth
😧 anguished
😨 fearful scared
😰 anxious sweat
😥 sad relieved
😢 crying sad tear
😭 sobbing crying loud
😱 scream fear shock
😖 confounded
😣 persevering
😞 disappointed
😓 downcast sweat
😩 weary tired
😫 tired exhausted
🥱 yawn bored
😤 triumph huff angry
😡 pouting angry mad
😠 angry
🤬 cursing swearing
😈 devil smiling
💀 skull dead lol
💩 poop
🤡 clown
👻 ghost
👽 alien
🤖 robot bot
😺 cat smiling
😹 cat joy
😻 cat heart eyes
🙈 see no evil monkey
🙉 hear no evil
🙊 speak no evil
'''),
  ),
  (
    name: 'Gestures',
    icon: Icons.back_hand_outlined,
    emojis: _parse('''
👍 thumbs up like yes agree
👎 thumbs down dislike no
👏 clap applause bravo
🙌 raising hands celebrate hooray
👐 open hands
🤲 palms up
🤝 handshake deal agree
🙏 pray please thanks folded hands
✍️ writing
👋 wave hello bye hi
🤚 raised back of hand
✋ raised hand stop high five
🖐️ hand fingers splayed
🖖 vulcan salute
👌 ok perfect
🤌 pinched fingers
🤏 pinching small
✌️ victory peace
🤞 crossed fingers luck hope
🫰 hand with index finger and thumb crossed money
🤟 love you gesture
🤘 rock on horns
🤙 call me shaka
👈 point left
👉 point right
👆 point up
👇 point down
☝️ index up
🫵 point at you
✊ raised fist
👊 fist bump punch
🤛 left fist bump
🤜 right fist bump
💪 flexed biceps strong
🫶 heart hands love
👀 eyes look see
🧠 brain smart idea
🫂 people hugging support
🗣️ speaking head talk
👤 person silhouette
👥 people silhouette group team
🧑‍💻 technologist developer coder laptop
🧑‍🏫 teacher
🧑‍💼 office worker manager
🙋 raising hand question
🤷 shrug dunno
🤦 facepalm
🙆 ok gesture
🙅 no gesture
💁 info desk person
'''),
  ),
  (
    name: 'Hearts',
    icon: Icons.favorite_border,
    emojis: _parse('''
❤️ red heart love
🧡 orange heart
💛 yellow heart
💚 green heart
💙 blue heart
💜 purple heart
🖤 black heart
🤍 white heart
🤎 brown heart
💔 broken heart sad
❤️‍🔥 heart on fire passion
❤️‍🩹 mending heart healing
❣️ heart exclamation
💕 two hearts
💞 revolving hearts
💓 beating heart
💗 growing heart
💖 sparkling heart
💘 heart arrow cupid
💝 heart ribbon gift
💯 hundred perfect score
💢 anger symbol
💥 collision boom
💫 dizzy star
💦 sweat drops
💨 dash fast
💬 speech balloon chat comment
💭 thought balloon thinking
🗯️ angry speech
💤 zzz sleep
'''),
  ),
  (
    name: 'Nature',
    icon: Icons.eco_outlined,
    emojis: _parse('''
🐶 dog puppy
🐱 cat kitten
🐭 mouse
🐰 rabbit bunny
🦊 fox
🐻 bear
🐼 panda
🐨 koala
🐯 tiger
🦁 lion
🐮 cow
🐷 pig
🐸 frog
🐵 monkey
🐔 chicken
🐧 penguin
🐦 bird
🦉 owl wise
🦄 unicorn
🐝 bee busy
🦋 butterfly
🐢 turtle slow
🐍 snake
🐙 octopus
🐬 dolphin
🐳 whale
🌵 cactus
🎄 christmas tree
🌲 evergreen tree
🌳 tree
🌴 palm tree
🌱 seedling growth
🌿 herb
🍀 four leaf clover luck
🍁 maple leaf autumn
🌷 tulip flower
🌹 rose flower
🌻 sunflower
🌸 cherry blossom
💐 bouquet flowers
🌞 sun face
🌝 full moon face
🌙 crescent moon night
⭐ star
🌟 glowing star
✨ sparkles magic new
⚡ lightning zap energy
🔥 fire hot lit
🌈 rainbow
☀️ sun sunny
⛅ partly cloudy
☁️ cloud
🌧️ rain
⛈️ storm thunder
❄️ snowflake cold
☃️ snowman
🌊 wave ocean
🌍 earth globe world
'''),
  ),
  (
    name: 'Food',
    icon: Icons.restaurant_outlined,
    emojis: _parse('''
🍏 green apple
🍎 red apple
🍊 orange tangerine
🍋 lemon
🍌 banana
🍉 watermelon
🍇 grapes
🍓 strawberry
🍒 cherries
🍑 peach
🥭 mango
🍍 pineapple
🥥 coconut
🥑 avocado
🥦 broccoli
🌽 corn
🥕 carrot
🥔 potato
🥐 croissant
🍞 bread
🧀 cheese
🥚 egg
🥞 pancakes
🥓 bacon
🍔 burger hamburger
🍟 fries
🍕 pizza
🌭 hot dog
🥪 sandwich
🌮 taco
🌯 burrito
🥗 salad
🍝 pasta spaghetti
🍜 noodles ramen
🍛 curry rice
🍣 sushi
🥟 dumpling momo
🍦 ice cream
🍩 doughnut donut
🍪 cookie
🎂 birthday cake
🍰 cake slice
🧁 cupcake
🍫 chocolate
🍿 popcorn
☕ coffee tea hot
🍵 tea
🧋 bubble tea boba
🥤 cup straw soda
🍺 beer
🍻 cheers beers
🥂 champagne toast celebrate
🍷 wine
🍽️ plate cutlery dinner
'''),
  ),
  (
    name: 'Activities',
    icon: Icons.sports_soccer_outlined,
    emojis: _parse('''
⚽ soccer football
🏀 basketball
🏈 american football
⚾ baseball
🎾 tennis
🏐 volleyball
🏏 cricket
🏓 ping pong
🏸 badminton
🥅 goal net
⛳ golf
🏃 running runner
🚴 cycling bike
🏊 swimming
🧘 yoga meditation calm
🏆 trophy winner award
🥇 gold medal first
🥈 silver medal second
🥉 bronze medal third
🏅 medal
🎖️ military medal
🎯 target goal bullseye
🎮 video game controller
🎲 dice game
🧩 puzzle piece
♟️ chess
🎨 art palette
🎬 movie clapper
🎤 microphone sing
🎧 headphones music
🎵 music note
🎶 notes music
🎸 guitar
🎹 piano keyboard
🥁 drum
🎉 party popper celebrate tada
🎊 confetti ball
🎈 balloon
🎁 gift present
🎗️ reminder ribbon
'''),
  ),
  (
    name: 'Travel',
    icon: Icons.directions_car_outlined,
    emojis: _parse('''
🚗 car
🚕 taxi
🚌 bus
🚑 ambulance
🚒 fire engine
🚓 police car
🚲 bicycle
🛵 scooter
🚂 train
🚇 metro subway
✈️ airplane flight
🚀 rocket launch ship
🛸 ufo
🚁 helicopter
⛵ sailboat
🚢 ship
⚓ anchor
🗺️ map
🧭 compass direction
🏔️ mountain snow
⛰️ mountain
🏕️ camping
🏖️ beach
🏝️ island
🏠 house home
🏡 house garden
🏢 office building work
🏫 school
🏥 hospital
🏦 bank
🏨 hotel
🕌 mosque
🛕 temple
⛪ church
🗼 tower
🗽 statue liberty
🌉 bridge night
🌃 city night
🌆 city dusk
🚦 traffic light
🚧 construction work in progress
'''),
  ),
  (
    name: 'Objects',
    icon: Icons.lightbulb_outline,
    emojis: _parse('''
💡 light bulb idea
🔦 flashlight
📱 phone mobile
💻 laptop computer
⌨️ keyboard
🖥️ desktop computer
🖨️ printer
🖱️ mouse computer
💾 floppy save
💿 disc
📷 camera photo
🎥 movie camera
📺 tv television
📞 telephone call
⏰ alarm clock
⏳ hourglass waiting
⌛ hourglass done
📅 calendar date
📆 tear off calendar
🗓️ spiral calendar schedule
📌 pushpin pin
📍 round pushpin location
📎 paperclip attach
✂️ scissors
📝 memo note write
✏️ pencil
🖊️ pen
📄 page document
📃 page curl
📑 bookmark tabs
📊 bar chart stats
📈 chart up growth
📉 chart down decline
📋 clipboard
📁 folder
📂 open folder
🗂️ dividers
📚 books study
📖 open book read
🔖 bookmark
🏷️ label tag
💰 money bag
💵 dollar
💳 credit card
🧾 receipt
📦 package box
📮 postbox
✉️ envelope mail
📧 email
📨 incoming envelope
📢 loudspeaker announcement
📣 megaphone
🔔 bell notification
🔕 bell off mute
🔒 lock locked private
🔓 unlocked
🔑 key
🛠️ tools
🔧 wrench fix
🔨 hammer build
⚙️ gear settings
🧪 test tube experiment
🔬 microscope
🔭 telescope
💊 pill medicine
🩺 stethoscope doctor
🧹 broom clean
🛒 shopping cart
🎓 graduation cap
💼 briefcase work
👓 glasses
'''),
  ),
  (
    name: 'Symbols',
    icon: Icons.tag,
    emojis: _parse('''
✅ check done yes
☑️ ballot check
✔️ check mark
❌ cross no wrong
❎ cross mark button
➕ plus add
➖ minus
➗ divide
✖️ multiply
❓ question
❔ white question
❗ exclamation important
❕ white exclamation
‼️ double exclamation
⁉️ exclamation question
⚠️ warning caution
🚫 prohibited no
⛔ no entry
🛑 stop sign
🔴 red circle
🟠 orange circle
🟡 yellow circle
🟢 green circle
🔵 blue circle
🟣 purple circle
⚫ black circle
⚪ white circle
🟥 red square
🟩 green square
🟦 blue square
🔺 red triangle up
🔻 red triangle down
🔶 orange diamond
🔷 blue diamond
➡️ right arrow
⬅️ left arrow
⬆️ up arrow
⬇️ down arrow
↩️ return back
🔄 refresh repeat
🔁 repeat
🔀 shuffle
▶️ play
⏸️ pause
⏹️ stop
⏭️ next
🔊 speaker loud
🔇 muted
🆕 new
🆗 ok button
🆒 cool button
🆙 up button
🆘 sos help
ℹ️ information
🔝 top
🔜 soon
💲 dollar sign
♻️ recycle
🏳️ white flag
🏁 chequered flag finish
🚩 red flag
🏴 black flag
🇳🇵 nepal flag
🇮🇳 india flag
🇺🇸 united states flag usa
🇬🇧 united kingdom flag uk
🇨🇦 canada flag
🇦🇺 australia flag
🇩🇪 germany flag
🇫🇷 france flag
🇯🇵 japan flag
#️⃣ hash number
1️⃣ one keycap
2️⃣ two keycap
3️⃣ three keycap
'''),
  ),
];

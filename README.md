<h1 align="center">Fess</h1>

<p align="center">
  <img src="assets/images/fess_thumbnail.png" alt="FessThumbnail" width="70%" />
</p>

<p align="center">
  An anonymous social app for confessions, tea, and honest conversatonis.
</p>

---

## What is Fess?

Fess is a mobile app where people post confessions, share "teas", and talk to each other without their real identity being reveled.its a safe space for all to share stories, confessions, and life's moments while connecting with people around the globe

## Why I built this

before this proggrame i got this this idea, from one of my friend. He didn't spoke to anyone, except me, gave me an idea to build an app where posting shouldn't feel like performance. anyone could share anything without the fear of getting judged !!

This was also my first real attempt at building a full app from scratch: real-time data, authentication, a chat system, and a UI I designed and coded myself.

## What all it haves

- **Spilss** - it can be a short annonymous confession posted to a public feed..
- **Tea** - a seperated feed for gossip, hot takes and things people are dying to sayyyy !!!! 
- **Likes and Comments** - reactions to posts wihtout needing to know who anyone is (can't give a negative reaction LMAO !!)
- **Anonymous persona** - everyone build their own customizable persona which remain with them, it is not real btw...
- **Direct message** - a real-time anonymous chats between user of same intrest ( they can be texted through their profile page, there's no otpion to search profiles)
- **World** - a mood-based matchmaking mode that connects you to random user who has similar or opposite intrests than you.
- **Profile** - A personal page showing your own Spills and tea, diffrent view if anyone else is viewing.
- **Streaks and notifications** - streaks to keep the suer engaged to post a confession or tea everyday.

## Screenshots

<p align="center">
  <img src="assets/images/screenshots_colg.png.png" width="70%" />
</p>

## Built with

- **Flutter & Dart** - the app itself
- **Firebase** - Firestore for the database, Firebase Auth for anonymous sign-in
- **Riverpod** - state management across the whole app
- **Hive** - local caching and offline storage
- **Lucide Icons** - icon set used throughout the UI

## Getting started

You will need Flutter installed on your machine.

1. Clone the repo:
   `git clone https://github.com/yourusername/fess.git
   cd fess`

2. Install dependencies:
   `flutter pub get
`

3. Create your own Firebase project at [firebase.google.com](https://firebase.google.com), enable Firestore and Anonymous Authentication, and download your own `google-services.json` file. Place it inside `android/app/`. This file is intentionally left out of the repo since it contains project-specific keys.

4. Run the app on a connected device or emulator:
   `flutter run`

## Building a release APK

If you just want to try the app without setting up, download the ready-made APK from the [Releases page](https://github.com/yuvakrishnas/fess/releases) instead of building from source.

To build it yourself:
`flutter build apk --release
`
**The finished file will be at `build/app/outputs/flutter-apk/app-release.apk`.**

## What's not finished yet

This is still a work in progress. Some of the stuff i need to still work on and perfect are:
- Uploading Images in confessions and tea both
- The World matchmaking flow needs more edge-case handling, also it is not also too realtime till now, gonna make it work well soon
- Push notifications are the lungs for the app, in app notifications work. I need to work on system notifications to engage users
- Improving security rules, measures, and i also need to refine some of the ui too

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
# Screen Monitor
The general idea is to be able to monitor your computer from your mobile while being away from it for example in a public place or even at home regardless of being on the same network or not. Besides viewing a capture of the desktop, you would receive other information such as battery level and temperatures and you could take urgent actions such as shutting down the computer when needed.

### Features

- Lightweight software on mobile and desktop
- Captures the desktop screen every **n** seconds, compresses it then uploads and broadcasts it to all connected devices
- Captures network throughput, CPU and GPU temperatures and the battery level of the computer
- Ability to change :
	- Upload interval in seconds (60 seconds by default)
	- Urgent action timer in seconds (60 seconds by default)
	- Urgent action type (shutdown by default)
- Realtime changes and updates, any settings changed from the desktop or the mobile application would take effect as soon as possible
- Supports only windows and android for the moment

### Technologies and frameworks used
- NodeJs for the [backend](https://github.com/HachichaRacem/screen_monitor_backend)
- Flutter for the frontend
- Supabase as cloud storage

### Screenshots
<img src="https://i.imgur.com/0JDWhjQ.jpeg" height="450">
<img src="https://i.imgur.com/kPXFfsc.png" width="720">
<img src="https://i.imgur.com/h4Tiptn.png" width="720">

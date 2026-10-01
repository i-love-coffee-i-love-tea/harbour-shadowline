# Shadow Line

An interactive globe for Sailfish OS showing real-time day/night shading and sunrise/sunset times.

![Globe with day/night terminator](screenshots/Screenshot_20261001_212629_001.png)
![Location list with sunrise/sunset times](screenshots/Screenshot_20261001_212653_001.png)
![Globe focused on Europe](screenshots/Screenshot_20261001_214253_001.png)
![Globe focused on Asia](screenshots/Screenshot_20261001_214311_001.png)
![Globe showing the Americas](screenshots/Screenshot_20261001_214319_001.png)
![Detailed location view](screenshots/Screenshot_20261001_223818_001.png)
![Full globe view](screenshots/Screenshot_20261001_224228_001.png)
![Location picker](screenshots/Screenshot_20261002_000355_001.png)
![Cover page](screenshots/Screenshot_20261002_000405_001.png)

## Features

- Interactive 3D globe with coastlines, country borders, and the sun's position
- Real-time day/night shading — the terminator line updates continuously
- Add locations from a built-in list of world capitals or enter custom coordinates (GPS supported)
- Sunrise and sunset times for each saved location, refreshed every minute
- Tap a location to fly the globe to it; drag to spin freely
- Cover page shows a mini globe with a countdown to the next sunrise or sunset for a pinned location
- Polar day and polar night detection
- Solar calculations based on the NOAA Solar Calculator algorithm (±1 minute accuracy)

## Building

Requires the Sailfish SDK. From the SDK build engine:

```bash
mb2 build
```

## License

MIT
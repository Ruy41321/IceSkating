# ❄️ Ice Skating - Cave Escape Puzzle

*An innovative puzzle game where players navigate through icy cave environments to find the exit. The game features slippery ice mechanics similar to classic Pokémon ice puzzles, combined with modern multiplayer capabilities and procedural map generation for endless gameplay.*

![Game Preview](extra/boot_splash.png)

## 🎮 Game Concept

*You find yourself trapped in an icy cave and must reach the exit by strategically using the environment. The core challenge lies in the slippery ice mechanics: once you start moving in a direction, you'll continue sliding until you hit a non-icy surface. Players must carefully plan their moves, avoid fragile ice that breaks after stepping on it, and navigate around deadly holes that end the game.*

## 🔧 Technical Challenges Overcome

### Server-Authoritative Multiplayer
*A robust anti-cheat system validates all game actions server-side while maintaining responsive gameplay through client prediction.*

### Procedural Map Generation
*A sophisticated C++ algorithm generates balanced, solvable cave layouts with appropriate difficulty scaling.*

### Client Prediction System
*A lag compensation system provides immediate visual feedback while ensuring server authority over game state.*

## 🛠️ Technologies Used

### Game Engine & Development
- **Engine**: Godot 4.4  
- **Programming**: GDScript for game logic  
- **Map Generation**: C++ algorithm for procedural map generation  
- **Cross-platform**: Windows and Android builds available  

### Backend Infrastructure
- **Server Architecture**: Docker containerized environment  
- **Dedicated Server**: Dedicated server to allow multiplayer matches  
- **Database**: MariaDB for user data and leaderboards  
- **APIs**: Node.js servers (public and private endpoints)  
- **Hosting**: Amazon AWS EC2 for global multiplayer support  
- **Authentication**: Secure user authentication system  
- **Matchmaking System**: Matchmaking system to manage both private and pubblic lobbies  


## ✨ Key Features

- ### 🏃 Training Mode (Offline)
  *Practice your skills with procedurally generated maps without the pressure of competition. Perfect for learning the game mechanics and improving your puzzle-solving abilities.*

- ### 🏆 Career Mode (Online)
  *Push your limits on progressively harder levels, both individually and with a friend's assistance.. Your performance affects your position in the global leaderboards.*

- ### 🥇 Ranked Mode (Online)
  *High-stakes competitive matches with dedicated ranking system and exclusive leaderboards for the most smartest players.*

- ### 🎲 Procedural Map Generation
  *Unlimited gameplay with algorithmically generated cave layouts ensuring each playthrough feels fresh and challenging.*

- ### 📊 Progression & Competition
  - **Dynamic Difficulty Scaling**: Maps adapt to player skill level  
  - **Global Leaderboards**: Separate rankings for Career and Ranked modes  
  - **User Authentication**: Secure account system with progress tracking  

- ### 🌍 Accessibility
  - **Cross-Platform**: Available on Windows and Android  
  - **Multi-Language Support**: Italian and English localization  
  - **Touch Controls**: Optimized mobile experience  

## 🎯 How to Play
### Controls
- **PC**: Use WASD or arrow keys to move in four directions  
- **Mobile**: Swipe gestures for intuitive touch controls  

### Objective
*Navigate through the icy cave to reach the exit while avoiding obstacles and managing the slippery ice mechanics.*

### Game Mechanics
- **Ice Sliding**: Continue moving in the same direction until hitting a stopping surface  
- **Rocks & Walls**: Stops the movement on collision  
- **Fragile Ice**: Breaks after stepping on it, creating holes  
- **Holes**: Instant game over if fallen into  
- **Normal Terrain**: Non-icy surfaces that stop your movement on them  
- **Strategic Planning**: Think ahead to avoid getting trapped  

## 🚀 Installation & Setup

### Playing the Game
*The game is ready to play with our hosted servers on AWS EC2. Download the builds from here:*
- **Download Builds**: [Google Drive - Game Builds](https://drive.google.com/drive/folders/1qtmo7OHy2XHLUU9rHWHgwRwqREM83YHT)
- **Windows**: Run `Ice Skating.exe`  
- **Android**: Install the APK file  

### Local Server Setup (Optional)
*For development or local hosting:*

1. **Prerequisites**: Install Docker and Docker Compose  
2. **Server Build**: Export a dedicated server version of the game in /docker/game_server/build
3. **Navigate to Docker folder**: `cd docker`  
4. **Start services**: `docker-compose up`  
5. **Configure endpoints**: Update IP addresses from in the code to point to local servers  

*The local environment includes:*
1. **Game server**: headless Godot instance  
2. **MariaDB database**  
3. **Public API server**  
4. **Private API server**  
5. **PHPMyAdmin**  

## 👥 Development Team

### 🎮 Executive & Game Designer
**Luigi Pennisi** ([GitHub Profile](https://github.com/Ruy41321))
- Game concept and design  
- Complete game mechanics implementation  
- Multiplayer architecture  
- Procedural map generation algorithm  

### 🎨 Artist
**Giuseppe Vigilante** ([GitHub Profile](https://github.com/GiuseppeVig))
- Game assets and visual design  
- UI/UX elements  

*Developed under SpaghettiStudio-42Roma gaming club*

## 🎖️ Project Status

*This is a **demo version** showcasing the core gameplay and technical capabilities. Future development plans if the demo receives positive reception include:*

- **Monetization System**: Character skins and pubblicity to gain extra lives  
- **Enhanced Graphics**: More polished visual experience  
- **Extended Gameplay**: Additional puzzle mechanics and cave types  
- **Mobile Publishing**: Official release on Play and App Store  

## 📁 Development Resources

- **Asset Storage**: [Google Drive](https://drive.google.com/drive/folders/1GC3aZYG6z29Hg-NGmGQCi6mqa-apE5wk?usp=sharing)

---

*Ice Skating represents the culmination of complex technical challenges in multiplayer game development, procedural content generation, and cross-platform deployment. Every slide counts in this icy adventure!*

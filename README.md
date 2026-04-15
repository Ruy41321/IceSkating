# ❄️ Ice Skating - Cave Escape Puzzle

*An innovative puzzle game where players navigate through icy cave environments to find the exit. The game features slippery ice mechanics similar to classic Pokémon ice puzzles, combined with modern multiplayer capabilities and procedural map generation for endless gameplay.*

**_click on the gif to be redirected to youtube for the full preview_**
[![Game Preview](extra/Preview.gif)](https://www.youtube.com/watch?v=A_HDVx65Yn8)

## 🎮 Game Concept

*You find yourself trapped in an icy cave and must reach the exit by strategically using the environment. The core challenge lies in the slippery ice mechanics: once you start moving in a direction, you'll continue sliding until you hit a non-icy surface. Players must carefully plan their moves, avoid fragile ice that breaks after stepping on it, and navigate around deadly holes that end the game.*

## 🔧 Technical Challenges Overcome

### 🎲 Procedural Map Generation
*A robust GDScript procedural generation algorithm creates maps with varying levels of complexity. The algorithm ensures that every generated map is not only fun, intriguing, and challenging, but also mathematically guaranteed to be solvable. It calculates the exact minimum number of moves required to reach the exit and scales the difficulty dynamically.*

### ⚡ Ultra-lightweight Backend Infrastructure
*The multiplayer backend is optimized to host multiple concurrent lobbies on a single server without lag. Instead of running heavy Godot game instances for each match, the server abstractly represents the game state using lightweight 2D array structures. Physics, collisions, and server-authoritative movements are managed meticulously through array manipulation and synchronization logic.*

```gdscript
# Example from room.gd: Memory-efficient map representation and state management
var map_grid: Array = []  # Grid representation of the map
var players_pos: Dictionary = {}  # Dictionary to store player positions by ID

func player_on_hole(player_id: int) -> bool:
	# Check if the player is on a hole tile using the 2D array
	if not players_pos.has(player_id):
		return false
	var pos = players_pos[player_id]
	if map_grid[pos.y][pos.x] == "B":
		players_pos[player_id] = Vector2(-1, -1)  # Reset position to invalid state
		return true
	return false
```

### 🔮 Custom Client Prediction System
*To maintain instantaneous feedback despite network latency, a custom low-level client prediction system was developed for sliding mechanics. Since the server doesn't run a native physics engine instance, clients predict their final position and visually slide toward it instantly. The system handles complex race conditions—such as two co-op players moving toward the same cell—transparently.*

```gdscript
# Example from player_online.gd: Handling predictions and race conditions
func handle_pre_movement_completion() -> bool:
	"""Handle player collision logic before movement completion"""
	if direction_when_going_on_player != Vector2(-1, -1):
		var next_pos = Vector2(final_grid_position.x, final_grid_position.y)
		next_pos.x += direction_when_going_on_player.x
		next_pos.y += direction_when_going_on_player.y
		if not is_position_occupied_by_other_player(next_pos):
			final_grid_position = calc_final_position(direction_when_going_on_player)
			direction_when_going_on_player = Vector2(-1, -1)  # Reset after prediction
			return true
	return false
```

## 🛠️ Technologies Used

### Game Engine & Development
- **Engine**: Godot 4.5  
- **Programming**: GDScript for game logic and procedural map generation    
- **Cross-platform**: Windows and Android builds available  

### Backend Infrastructure
- **Server Architecture**: Docker containerized environment  
- **Dedicated Server**: Dedicated server to allow multiplayer matches  
- **Database**: MariaDB for user data and leaderboards  
- **APIs**: Node.js servers (public and private endpoints)  
- **Hosting**: Amazon AWS EC2 for global multiplayer support  
- **Authentication**: Secure user authentication system  
- **Matchmaking System**: Matchmaking system to manage both private and pubblic lobbies  


## ✨ Key Features & Game Modes

### 🎮 Comprehensive Game Modes
- **Training Mode (Offline)**: Always available without server authentication. Maps are generated smartly in the background using local GDScript logic to eliminate wait times between levels.
- **Career Mode (Online)**: Can be played purely Solo or in Duo Co-op. Progression is tracked against a global Career leaderboard indicating the total number of solved levels.
- **Ranked Mode (Online)**: A highly competitive Solo-only mode tied to a separate, exclusive global Ranked leaderboard.
*Note: All online matches are strictly server-authoritative to ensure 100% reliable and cheat-free leaderboards.*

### 🔐 Cross-platform Login & Map DB Optimization
*A secure login system tracks player progress (Career and Ranked) across multiple devices. To optimize server workload, generated maps are cached in our database. When playing online, the server checks the player's previously completed maps and retrieves fresh, pre-cached challenges generated by other players. The server only computes a new map generation if the player exhausts the pool of available cached maps.*

### 🤝 Matchmaking & Private Lobbies
*The multiplayer experience flexibly supports both quick matchmaking for finding random co-op partners online, and a Private Lobby system. You can generate a unique room code and share it with a friend to easily play together in your private session.*

### 🌍 Accessibility
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
2. **Clone this Repository**: [GitHub - Dedicated Server](https://github.com/Ruy41321/IceSkatingDedicatedServer)  
3. **Start the Containers**: Follow the instruction in the Readme  
5. **Configure endpoints**: Update IP addresses from in the code to point to your local server  

*The local environment includes:*
1. **Game server**: headless Godot instance  
2. **MariaDB database**  
3. **Public API server**  
4. **Private API server**  
5. **PHPMyAdmin**  

## 👥 Development Team

### 🎮 Executive, Game Designer &  Programmer
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
  

---

*Ice Skating represents the culmination of complex technical challenges in multiplayer game development, procedural content generation, and cross-platform deployment. Every slide counts in this icy adventure!*

![Game Preview](extra/boot_splash.png)

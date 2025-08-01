#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <random>
#include <ctime>
#include <algorithm>

// Struttura per restituire sia le mosse che il percorso completo
struct PathResult {
    int min_moves;              // Solo i cambi di direzione
    std::vector<int> full_path; // Tutte le mosse effettive
};

// Struttura per restituire i risultati della ricerca Dijkstra
struct DijkstraResult {
    std::vector<std::vector<std::vector<int>>> distance;
    std::vector<std::vector<std::vector<std::tuple<int, int, int>>>> parent;
};

// Funzioni utility
std::string directionToString(int dir) {
    switch (dir) {
        case 0: return "DESTRA";
        case 1: return "SINISTRA";
        case 2: return "GIU";
        case 3: return "SU";
        default: return "SCONOSCIUTA";
    }
}

bool isValidPosition(int x, int y, int width, int height) {
    return x >= 0 && x < width && y >= 0 && y < height;
}

bool isWall(const std::vector<std::vector<char>>& map, int x, int y) {
    return map[y][x] == 'M';
}

bool isIce(const std::vector<std::vector<char>>& map, int x, int y) {
    return map[y][x] == 'G';
}

bool isStoppingTerrain(const std::vector<std::vector<char>>& map, int x, int y) {
    return map[y][x] == 'T' || map[y][x] == 'I' || map[y][x] == 'E';
}

// Nuova funzione per verificare se una posizione è un nastro trasportatore
bool isConveyorBelt(const std::vector<std::vector<char>>& map, int x, int y) {
    char cell = map[y][x];
    return cell == '1' || cell == '2' || cell == '3' || cell == '4';
}

// Funzione per ottenere la direzione del nastro trasportatore
int getConveyorDirection(const std::vector<std::vector<char>>& map, int x, int y) {
    char cell = map[y][x];
    switch (cell) {
        case '1': return 0; // DESTRA
        case '2': return 1; // SINISTRA
        case '3': return 2; // GIU
        case '4': return 3; // SU
        default: return -1;
    }
}

// Nuova funzione per verificare se una posizione è ghiaccio fragile
bool isFragileIce(const std::vector<std::vector<char>>& map, int x, int y) {
    return map[y][x] == 'D';
}

// Funzione aggiornata per verificare se una posizione è mortale (include ghiaccio rotto)
bool isDeadlyTerrain(const std::vector<std::vector<char>>& map, int x, int y) {
    return map[y][x] == 'B' || map[y][x] == 'X'; // X = ghiaccio fragile rotto
}

// Funzione per simulare il movimento con scivolamento (aggiornata per nastri trasportatori)
std::pair<int, int> simulateMove(const std::vector<std::vector<char>>& map, int x, int y, int dx, int dy) {
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    
    int new_x = x + dx;
    int new_y = y + dy;
    
    // Controlla confini
    if (!isValidPosition(new_x, new_y, width, height)) {
        return {x, y}; // Non si muove
    }
    
    // Se colpisce un muro, non si muove
    if (isWall(map, new_x, new_y)) {
        return {x, y};
    }
    
    // Se finisce su un buco o ghiaccio rotto, game over
    if (isDeadlyTerrain(map, new_x, new_y)) {
        return {new_x, new_y}; // Finisce nel buco/ghiaccio rotto = morte
    }
    
    // Variabili per la direzione attuale di movimento
    int current_dx = dx;
    int current_dy = dy;
    
    // Se finisce su un nastro trasportatore, viene spinto e cambia direzione
    if (isConveyorBelt(map, new_x, new_y)) {
        int conveyor_dir = getConveyorDirection(map, new_x, new_y);
        int conv_dx[] = {1, -1, 0, 0}; // destra, sinistra, giù, su
        int conv_dy[] = {0, 0, 1, -1};
        
        // Spinto di una cella nella direzione del nastro
        int pushed_x = new_x + conv_dx[conveyor_dir];
        int pushed_y = new_y + conv_dy[conveyor_dir];
        
        // Controlla se la posizione spinta è valida
        if (isValidPosition(pushed_x, pushed_y, width, height) && !isWall(map, pushed_x, pushed_y)) {
            new_x = pushed_x;
            new_y = pushed_y;
            
            // IMPORTANTE: Cambia la direzione di movimento a quella del nastro
            current_dx = conv_dx[conveyor_dir];
            current_dy = conv_dy[conveyor_dir];
            
            // Se finisce su un buco dopo essere stato spinto, game over
            if (isDeadlyTerrain(map, new_x, new_y)) {
                return {new_x, new_y};
            }
        }
    }
    
    // Limite di sicurezza per prevenire loop infiniti
    int iterations = 0;
    const int MAX_ITERATIONS = std::max(width, height); // Limite basato sulla dimensione della mappa
    
    // Se finisce su ghiaccio normale o fragile, continua a scivolare
    while ((isIce(map, new_x, new_y) || isFragileIce(map, new_x, new_y)) && iterations < MAX_ITERATIONS) {
        iterations++;
        
        // USA LA DIREZIONE ATTUALE (che può essere cambiata dal nastro)
        int next_x = new_x + current_dx;
        int next_y = new_y + current_dy;
        
        // Controlla confini
        if (!isValidPosition(next_x, next_y, width, height)) {
            break;
        }
        
        // Se il prossimo è un muro, si ferma sulla posizione attuale
        if (isWall(map, next_x, next_y)) {
            break;
        }
        
        new_x = next_x;
        new_y = next_y;
        
        // Se finisce su un buco o ghiaccio rotto durante lo scivolamento, game over
        if (isDeadlyTerrain(map, new_x, new_y)) {
            return {new_x, new_y}; // Morte durante lo scivolamento
        }
        
        // Se finisce su terreno normale o I/E, si ferma
        if (isStoppingTerrain(map, new_x, new_y)) {
            break;
        }
        
        // Se finisce su un nastro trasportatore durante lo scivolamento
        if (isConveyorBelt(map, new_x, new_y)) {
            int conveyor_dir = getConveyorDirection(map, new_x, new_y);
            int conv_dx[] = {1, -1, 0, 0};
            int conv_dy[] = {0, 0, 1, -1};
            
            // Spinto di una cella nella direzione del nastro
            int pushed_x = new_x + conv_dx[conveyor_dir];
            int pushed_y = new_y + conv_dy[conveyor_dir];
            
            // Controlla se può essere spinto
            if (isValidPosition(pushed_x, pushed_y, width, height) && !isWall(map, pushed_x, pushed_y)) {
                new_x = pushed_x;
                new_y = pushed_y;
                
                // IMPORTANTE: Cambia nuovamente la direzione di movimento
                current_dx = conv_dx[conveyor_dir];
                current_dy = conv_dy[conveyor_dir];
                
                // Se finisce su un buco dopo essere stato spinto, game over
                if (isDeadlyTerrain(map, new_x, new_y)) {
                    return {new_x, new_y};
                }
                
                // Se finisce su terreno che ferma dopo essere stato spinto, si ferma
                if (isStoppingTerrain(map, new_x, new_y)) {
                    break;
                }
                
                // Continua a scivolare nella NUOVA direzione
                // (il while continuerà l'iterazione con current_dx e current_dy aggiornati)
            } else {
                // Non può essere spinto, si ferma sul nastro
                break;
            }
        }
    }
    
    return {new_x, new_y};
}

// Funzione per verificare se esiste un percorso da I a E (corretta per nastri trasportatori)
bool hasValidPath(const std::vector<std::vector<char>>& map, int start_x, int start_y, int end_x, int end_y) {
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    
    // Usa un set per tracciare stati visitati: (x, y, direzione_arrivo)
    // Questo previene loop infiniti con i nastri trasportatori
    std::vector<std::vector<std::vector<bool>>> visited(height, 
        std::vector<std::vector<bool>>(width, std::vector<bool>(5, false)));
    
    // Usa deque invece di vector per una queue efficiente
    std::vector<std::tuple<int, int, int>> queue; // x, y, direzione_arrivo
    int queue_front = 0; // Indice del front della queue
    
    queue.push_back({start_x, start_y, 4}); // 4 = stato iniziale
    visited[start_y][start_x][4] = true;
    
    // Direzioni: destra, sinistra, giù, su
    int dx[] = {1, -1, 0, 0};
    int dy[] = {0, 0, 1, -1};
    
    int iterations = 0;

    while (queue_front < static_cast<int>(queue.size()) ) {
        iterations++;
        auto [x, y, last_dir] = queue[queue_front];
        queue_front++; // Simula pop_front senza cancellare
        if (x == end_x && y == end_y) {
            return true;
        }
        
        // Prova tutte le direzioni
        for (int i = 0; i < 4; i++) {
            auto [new_x, new_y] = simulateMove(map, x, y, dx[i], dy[i]);
            // Se non si muove o finisce in un buco, questa mossa non è valida
            if ((new_x == x && new_y == y) || isDeadlyTerrain(map, new_x, new_y)) {
                continue;
            }
            
            // Controlla se questo stato è già stato visitato
            if (!visited[new_y][new_x][i]) {
                visited[new_y][new_x][i] = true;
                queue.push_back({new_x, new_y, i});
            }
        }
    }
    
    return false;
}

// Calcola il costo del movimento (Dijkstra modificato per i buchi)
DijkstraResult runDijkstraSearch(const std::vector<std::vector<char>>& map, int start_x, int start_y) {
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    
    std::vector<std::vector<std::vector<int>>> distance(height, std::vector<std::vector<int>>(width, std::vector<int>(5, -1)));
    std::vector<std::vector<std::vector<std::tuple<int, int, int>>>> parent(height, std::vector<std::vector<std::tuple<int, int, int>>>(width, std::vector<std::tuple<int, int, int>>(5, {-1, -1, -1})));
    std::vector<std::tuple<int, int, int>> queue;
    
    queue.push_back({start_x, start_y, 4});
    distance[start_y][start_x][4] = 0;
    
    int dx[] = {1, -1, 0, 0};
    int dy[] = {0, 0, 1, -1};
    
    int iterations = 0;
    
    while (!queue.empty()) {
        iterations++;
        
        auto [x, y, last_dir] = queue.front();
        queue.erase(queue.begin());
        
        for (int i = 0; i < 4; i++) {
            auto [new_x, new_y] = simulateMove(map, x, y, dx[i], dy[i]);
            
            // Se non si muove o finisce in un buco, salta
            if ((new_x == x && new_y == y) || isDeadlyTerrain(map, new_x, new_y)) {
                continue;
            }
            
            // Il costo è sempre basato sui cambi di direzione
            int move_cost = (last_dir == 4 || last_dir != i) ? 1 : 0;
            int new_distance = distance[y][x][last_dir] + move_cost;
            
            if (distance[new_y][new_x][i] == -1 || distance[new_y][new_x][i] > new_distance) {
                distance[new_y][new_x][i] = new_distance;
                parent[new_y][new_x][i] = {x, y, last_dir};
                queue.push_back({new_x, new_y, i});
            }
        }
    }
	
    return {distance, parent};
}

// Trova la migliore direzione finale
int findBestFinalDirection(const std::vector<std::vector<std::vector<int>>>& distance, int end_x, int end_y) {
    int best_dir = -1;
    int min_moves = -1;
    
    for (int dir = 0; dir < 5; dir++) {
        if (distance[end_y][end_x][dir] != -1) {
            if (min_moves == -1 || distance[end_y][end_x][dir] < min_moves) {
                min_moves = distance[end_y][end_x][dir];
                best_dir = dir;
            }
        }
    }
    
    return best_dir;
}

// Ricostruisce la sequenza di cambi di direzione
std::vector<int> reconstructDirectionChanges(const std::vector<std::vector<std::vector<std::tuple<int, int, int>>>>& parent, 
                                           int start_x, int start_y, int end_x, int end_y, int best_dir) {
    std::vector<int> direction_changes;
    int trace_x = end_x, trace_y = end_y, trace_dir = best_dir;
    
    while (!(trace_x == start_x && trace_y == start_y && trace_dir == 4)) {
        auto [parent_x, parent_y, parent_dir] = parent[trace_y][trace_x][trace_dir];
        
        if (parent_dir == 4 || parent_dir != trace_dir) {
            direction_changes.push_back(trace_dir);
        }
        
        trace_x = parent_x;
        trace_y = parent_y;
        trace_dir = parent_dir;
    }
    
    std::reverse(direction_changes.begin(), direction_changes.end());
    return direction_changes;
}

// Ricostruisce la sequenza completa di tutte le mosse (non solo i cambi)
std::vector<int> reconstructFullMovePath(const std::vector<std::vector<std::vector<std::tuple<int, int, int>>>>& parent, 
                                        const std::vector<std::vector<char>>& map,
                                        int start_x, int start_y, int end_x, int end_y, int best_dir) {
    std::vector<std::tuple<int, int, int>> path_states; // (x, y, direzione)
    int trace_x = end_x, trace_y = end_y, trace_dir = best_dir;
    
    // Ricostruisci il percorso di stati
    while (!(trace_x == start_x && trace_y == start_y && trace_dir == 4)) {
        path_states.push_back({trace_x, trace_y, trace_dir});
        auto [parent_x, parent_y, parent_dir] = parent[trace_y][trace_x][trace_dir];
        
        trace_x = parent_x;
        trace_y = parent_y;
        trace_dir = parent_dir;
    }
    
    std::reverse(path_states.begin(), path_states.end());
    
    // Converte gli stati in mosse effettive
    std::vector<int> full_moves;
    int curr_x = start_x, curr_y = start_y;
    
    int dx[] = {1, -1, 0, 0};
    int dy[] = {0, 0, 1, -1};
    
    for (const auto& [target_x, target_y, direction] : path_states) {
        // Simula tutte le mosse necessarie per raggiungere questo stato
        while (curr_x != target_x || curr_y != target_y) {
            auto [next_x, next_y] = simulateMove(map, curr_x, curr_y, dx[direction], dy[direction]);
            
            // Se non si muove, c'è un errore nella ricostruzione
            if (next_x == curr_x && next_y == curr_y) {
                break;
            }
            
            full_moves.push_back(direction);
            curr_x = next_x;
            curr_y = next_y;
        }
    }
    
    return full_moves;
}

// Funzione principale per calcolare mosse minime e percorso completo
PathResult calculateMinMovesAndPath(const std::vector<std::vector<char>>& map, int start_x, int start_y, int end_x, int end_y) {
    // Esegui ricerca Dijkstra
    auto search_result = runDijkstraSearch(map, start_x, start_y);
    auto& distance = search_result.distance;
    auto& parent = search_result.parent;
    
    // Trova la migliore direzione finale
    int best_dir = findBestFinalDirection(distance, end_x, end_y);
    
    if (best_dir == -1) {
        return {-1, {}};
    }
    
    int min_moves = distance[end_y][end_x][best_dir];
    // Se il risultato è valido, ricostruisci il percorso
    if (min_moves != -1) {
        std::vector<int> full_path = reconstructFullMovePath(parent, map, start_x, start_y, end_x, end_y, best_dir);
        return {min_moves, full_path};
    } else {
        return {-1, {}};
    }
}

// Inizializza una mappa vuota con bordi di muri
std::vector<std::vector<char>> createEmptyMap(int width, int height) {
    std::vector<std::vector<char>> map(height, std::vector<char>(width, 'M'));
    
    // Riempi l'interno con ghiaccio
    for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
            map[y][x] = 'G';
        }
    }
    
    return map;
}

// Posiziona ingresso e uscita casualmente
void placeStartAndEnd(std::vector<std::vector<char>>& map, std::mt19937& rng, 
                     int& start_x, int& start_y, int& end_x, int& end_y) {
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    
    start_x = 1 + rng() % (width - 2);
    start_y = 1 + rng() % (height - 2);
    map[start_y][start_x] = 'I';
    
    do {
        end_x = 1 + rng() % (width - 2);
        end_y = 1 + rng() % (height - 2);
    } while (end_x == start_x && end_y == start_y);
    map[end_y][end_x] = 'E';
}

// Aggiunge terreno normale casualmente
void addNormalTerrain(std::vector<std::vector<char>>& map, std::mt19937& rng, 
                     int difficulty, int start_x, int start_y, int end_x, int end_y) {
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    int normal_terrain_count = (width * height) / (35 + difficulty * 5);
    
    for (int i = 0; i < normal_terrain_count; i++) {
        int x, y;
        int attempts = 0;
        do {
            x = 1 + rng() % (width - 2);
            y = 1 + rng() % (height - 2);
            attempts++;
        } while ((map[y][x] != 'G' || (x == start_x && y == start_y) || (x == end_x && y == end_y)) && attempts < 50);
        
        if (attempts < 50) {
            map[y][x] = 'T';
        }
    }
}

// Aggiunge ostacoli di varie dimensioni
void addObstacles(std::vector<std::vector<char>>& map, std::mt19937& rng, 
                 int difficulty, int start_x, int start_y, int end_x, int end_y) {
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    int internal_walls = difficulty * 5 + (width * height) / 25;
    
    for (int i = 0; i < internal_walls; i++) {
        int x, y;
        int attempts = 0;
        do {
            x = 1 + rng() % (width - 2);
            y = 1 + rng() % (height - 2);
            attempts++;
        } while ((map[y][x] != 'G' || (x == start_x && y == start_y) || (x == end_x && y == end_y)) && attempts < 100);
        
        if (attempts < 100) {
            int obstacle_size = 1 + rng() % 3; // 1x1, 2x2, o 3x3
            
            for (int dy = 0; dy < obstacle_size && y + dy < height - 1; dy++) {
                for (int dx = 0; dx < obstacle_size && x + dx < width - 1; dx++) {
                    if (map[y + dy][x + dx] == 'G') {
                        map[y + dy][x + dx] = 'M';
                    }
                }
            }
        }
    }
}

// Aggiunge muri singoli sparsi
void addScatteredWalls(std::vector<std::vector<char>>& map, std::mt19937& rng) {
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    int single_walls = (width * height) / 15;
    
    for (int i = 0; i < single_walls; i++) {
        int x = 1 + rng() % (width - 2);
        int y = 1 + rng() % (height - 2);
        
        if (map[y][x] == 'G') {
            map[y][x] = 'M';
        }
    }
}

// Aggiunge buchi mortali (solo per difficoltà 3+)
void addDeadlyHoles(std::vector<std::vector<char>>& map, std::mt19937& rng, 
                   int difficulty, int start_x, int start_y, int end_x, int end_y) {
    // Buchi solo dalla difficoltà 3 in su
    if (difficulty < 3) {
        return;
    }
    
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    
    // Numero di buchi basato sulla difficoltà: più è difficile, più buchi ci sono
    int hole_count = (difficulty - 2) * 2 + (width * height) / 100;
    
    for (int i = 0; i < hole_count; i++) {
        int x, y;
        int attempts = 0;
        do {
            x = 1 + rng() % (width - 2);
            y = 1 + rng() % (height - 2);
            attempts++;
        } while ((map[y][x] != 'G' || (x == start_x && y == start_y) || (x == end_x && y == end_y)) && attempts < 50);
        
        if (attempts < 50) {
            map[y][x] = 'B';
        }
    }
}

// Aggiunge ghiaccio fragile (solo per difficoltà 2+)
void addFragileIce(std::vector<std::vector<char>>& map, std::mt19937& rng, 
                   int difficulty, int start_x, int start_y, int end_x, int end_y) {
    // Ghiaccio fragile dalla difficoltà 2 in su
    if (difficulty < 2) {
        return;
    }
    
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    
    // Numero di piastrelle fragili basato sulla difficoltà
    int fragile_count = (difficulty - 1) * 3 + (width * height) / 80;
    
    for (int i = 0; i < fragile_count; i++) {
        int x, y;
        int attempts = 0;
        do {
            x = 1 + rng() % (width - 2);
            y = 1 + rng() % (height - 2);
            attempts++;
        } while ((map[y][x] != 'G' || (x == start_x && y == start_y) || (x == end_x && y == end_y)) && attempts < 50);
        
        if (attempts < 50) {
            map[y][x] = 'D';
        }
    }
}
// Aggiunge nastri trasportatori (solo per difficoltà 4+)
void addConveyorBelts(std::vector<std::vector<char>>& map, std::mt19937& rng, 
                      int difficulty, int start_x, int start_y, int end_x, int end_y) {
    // Nastri trasportatori dalla difficoltà 4 in su
    if (difficulty < 4) {
        return;
    }
    
    int width = static_cast<int>(map[0].size());
    int height = static_cast<int>(map.size());
    
    // Numero di nastri basato sulla difficoltà
    int conveyor_count = (difficulty - 3) * 2 + (width * height) / 120;
    
    // Array per le direzioni: destra, sinistra, giù, su
    int conv_dx[] = {1, -1, 0, 0};
    int conv_dy[] = {0, 0, 1, -1};
    
    for (int i = 0; i < conveyor_count; i++) {
        int x, y;
        int attempts = 0;
        do {
            x = 1 + rng() % (width - 2);
            y = 1 + rng() % (height - 2);
            attempts++;
        } while ((map[y][x] != 'G' || (x == start_x && y == start_y) || (x == end_x && y == end_y)) && attempts < 50);
        
        if (attempts < 50) {
            // Trova tutte le direzioni valide (che non puntano verso un muro)
            std::vector<int> valid_directions;
            
            for (int dir = 0; dir < 4; dir++) {
                int target_x = x + conv_dx[dir];
                int target_y = y + conv_dy[dir];
                
                // Controlla se la posizione target è valida e non è un muro
                if (isValidPosition(target_x, target_y, width, height) && !isWall(map, target_x, target_y)) {
                    valid_directions.push_back(dir + 1); // +1 perché i nastri usano 1-4, non 0-3
                }
            }
            
            // Se ci sono direzioni valide, scegline una casualmente
            if (!valid_directions.empty()) {
                int random_index = rng() % valid_directions.size();
                int direction = valid_directions[random_index];
                map[y][x] = '0' + direction; // Converte numero in carattere
            }
            // Se non ci sono direzioni valide, non piazzare il nastro (rimane 'G')
        }
    }
}
// Genera una singola mappa con tutti gli elementi (aggiornata per nastri trasportatori)
std::vector<std::vector<char>> generateSingleMap(std::mt19937& rng, int width, int height, int difficulty,
                                                int& start_x, int& start_y, int& end_x, int& end_y) {
    auto map = createEmptyMap(width, height);
    placeStartAndEnd(map, rng, start_x, start_y, end_x, end_y);
    addNormalTerrain(map, rng, difficulty, start_x, start_y, end_x, end_y);
    addObstacles(map, rng, difficulty, start_x, start_y, end_x, end_y);
    addScatteredWalls(map, rng);
    addFragileIce(map, rng, difficulty, start_x, start_y, end_x, end_y);
    addConveyorBelts(map, rng, difficulty, start_x, start_y, end_x, end_y);
    addDeadlyHoles(map, rng, difficulty, start_x, start_y, end_x, end_y);
    
    return map;
}

// Stampa informazioni sulla mappa generata
void printMapInfo(int count, const PathResult& result) {
    std::cout << "Mappa valida trovata dopo " << count << " tentativi." << std::endl;
    std::cout << "Numero minimo di mosse richieste (cambi direzione): " << result.min_moves << std::endl;
    std::cout << "Sequenza completa di direzioni (" << result.full_path.size() << " mosse totali):" << std::endl;
    
    for (size_t i = 0; i < result.full_path.size(); i++) {
        std::cout << (i + 1) << ". " << directionToString(result.full_path[i]) << std::endl;
    }
}

// Scrive l'header del file mappa (aggiornato per ghiaccio fragile)
void writeMapHeader(std::ofstream& file, int difficulty, const PathResult& result, 
                   int width, int height) {
    file << "# Mappa generata con difficolta: " << difficulty << std::endl;
    file << "# Terreni: M=Muro, G=Ghiaccio, T=Terreno normale, I=Ingresso, E=Uscita";
    if (difficulty >= 2) {
        file << ", D=Ghiaccio fragile (si rompe dopo 1 passaggio)";
    }
    if (difficulty >= 3) {
        file << ", B=Buco (mortale)";
    }
    if (difficulty >= 4) {
        file << ", 1234=Nastri trasportatori (1=su, 2=sinistra, 3=giù, 4=destra)";
    }
    file << std::endl;
    file << "# Mosse minime richieste (cambi direzione): " << result.min_moves << std::endl;
    file << "# Mosse totali nella sequenza: " << result.full_path.size() << std::endl;
    file << "# Sequenza completa: ";
    for (size_t i = 0; i < result.full_path.size(); i++) {
        if (i > 0) file << " -> ";
        file << directionToString(result.full_path[i]);
    }
    file << std::endl;
    file << "width=" << width << std::endl;
    file << "height=" << height << std::endl;
    file << "difficulty=" << difficulty << std::endl;
    file << "min_moves=" << result.min_moves << std::endl;
    file << "total_moves=" << result.full_path.size() << std::endl;
    file << std::endl;
}

// Scrive la griglia della mappa
void writeMapGrid(std::ofstream& file, const std::vector<std::vector<char>>& map) {
    int height = static_cast<int>(map.size());
    int width = static_cast<int>(map[0].size());
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            file << map[y][x];
        }
        file << std::endl;
    }
}

// Funzione principale di generazione mappa
void generateMap(std::ofstream& file, int difficulty) {
    // Validazione difficoltà
    if (difficulty < 1 || difficulty > 5) {
        std::cerr << "Errore: la difficolta deve essere tra 1 e 5." << std::endl;
        return;
    }
    
    // Parametri configurabili basati sulla difficoltà
    const int MIN_SIZE = 8 + difficulty * 2;        // 10-18
    const int MAX_SIZE = 15 + difficulty * 8;       // 23-55
    const int MIN_MOVES = difficulty * 5 + 3;       // 8-28 mosse minime
    const int MAX_ATTEMPTS = 1000;                  // Limite massimo tentativi
    
    // Genera dimensioni casuali
    std::mt19937 rng(std::time(nullptr));
    int width = MIN_SIZE + (rng() % (MAX_SIZE - MIN_SIZE + 1));
    int height = MIN_SIZE + (rng() % (MAX_SIZE - MIN_SIZE + 1));
    
    std::vector<std::vector<char>> map;
    int start_x, start_y, end_x, end_y;
    int count = 0;
    PathResult result = {0, {}};
    
    // Genera mappe finché non ne trovi una valida e sufficientemente difficile
    do {
        count++;
        
        // Controllo limite tentativi
        if (count > MAX_ATTEMPTS) {
            std::cerr << "Errore: impossibile generare una mappa valida dopo " << MAX_ATTEMPTS << " tentativi." << std::endl;
            std::cerr << "Prova a ridurre la difficolta o modificare i parametri." << std::endl;
            exit(-104);
        }
        
        // Genera una nuova mappa
        map = generateSingleMap(rng, width, height, difficulty, start_x, start_y, end_x, end_y);
        
        // Verifica che esista un percorso valido
        if (hasValidPath(map, start_x, start_y, end_x, end_y)) {
            result = calculateMinMovesAndPath(map, start_x, start_y, end_x, end_y);
        } else {
            result = {-1, {}};
        }
        // Mostra progresso ogni 100 tentativi
        if (count % 100 == 0) {
            std::cout << "Tentativo " << count << "/1000..." << std::endl;
        }
        
    } while (result.min_moves < MIN_MOVES || result.min_moves == -1);
    
    // Stampa informazioni e scrivi file
    printMapInfo(count, result);
    writeMapHeader(file, difficulty, result, width, height);
    writeMapGrid(file, map);
}

int main(int argc, char* argv[]) {
    // Controllo parametri
    if (argc != 3) {
        std::cerr << "Uso: " << argv[0] << " <nome_file> <livello_difficolta>" << std::endl;
        std::cerr << "Esempio: " << argv[0] << " mappa1 2" << std::endl;
        std::cerr << "Difficolta: 1-5 (1=facile, 5=molto difficile)" << std::endl;
        return 1;
    }
    
    std::string filename = argv[1];
    int difficulty_level;
    
    // Controllo se il livello di difficoltà è un numero valido
    try {
        difficulty_level = std::stoi(argv[2]);
        if (difficulty_level < 1 || difficulty_level > 5) {
            std::cerr << "Errore: il livello di difficolta deve essere tra 1 e 5." << std::endl;
            return 1;
        }
    } catch (const std::exception& e) {
        std::cerr << "Errore: il livello di difficolta deve essere un numero tra 1 e 5." << std::endl;
        return 1;
    }
    
    // Aggiungi estensione .map se non presente
    if (filename.find(".map") == std::string::npos) {
        filename += ".map";
    }
    filename = "../ice-skating/maps/" + filename;
    
    // Crea il file
    std::ofstream mapFile(filename);
    if (!mapFile.is_open()) {
        std::cerr << "Errore: impossibile creare il file " << filename << std::endl;
        return 1;
    }
    
    std::cout << "Generando mappa: " << filename << " con difficolta: " << difficulty_level << std::endl;
    
    generateMap(mapFile, difficulty_level);
    
    mapFile.close();
    std::cout << "Mappa generata con successo!" << std::endl;
    
    return 0;
}
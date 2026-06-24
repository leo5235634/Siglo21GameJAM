# Documentacion del proyecto Siglo21Jam

Este documento explica como funciona el codigo actual del juego, como se conectan las escenas principales y que partes se pueden modificar o mejorar.

## Resumen general

El proyecto es un juego 2D en Godot donde el jugador se mueve, ataca automaticamente con hasta 2 armas, recibe daño si un enemigo se acerca, mata enemigos, recoge gemas de experiencia y sube de nivel. Al subir de nivel, el juego se pausa y aparece un menu con 3 mejoras seleccionables.

El ciclo principal es:

1. El nivel instancia al `Player`, enemigos iniciales y un `spawn`.
2. El `spawn` crea enemigos cada cierto tiempo.
3. El `Player` detecta enemigos cercanos con un `Area2D`.
4. Cada arma del `Player` ataca cuando termina su cooldown.
5. Los proyectiles y lasers priorizan enemigos cercanos; si no hay objetivo, disparan en direcciones libres para obligar al jugador a moverse y posicionarse.
6. Cuando el enemigo muere, suelta una gema.
7. Si el jugador pasa por encima de la gema, recibe experiencia.
8. Al subir de nivel, `Stats` cura al jugador al maximo y emite una señal.
9. El `Player` abre el menu de mejoras.
10. El menu pausa el juego hasta que se elige una mejora.

## Notas del GDD

El GDD compartido define el juego como `pipes n gears`: un juego 2D con ambientacion steampunk/industrial, ingenieros, mecanicos, electricistas, robots y supervivencia por tiempo. El personaje debe moverse, juntar gemas, subir de nivel, recibir mejoras, tener barra de vida, usar armas y morir.

Controles definidos por el GDD:

- Movimiento con `ASDW`.
- Seleccion de menus con click o enter.

Mecanicas alineadas actualmente:

- Movimiento del personaje.
- Recoleccion de gemas.
- Subida de nivel.
- Tres mejoras al azar y eleccion de una.
- Barra de vida.
- Enemigos que se acercan al jugador.

Ideas futuras del GDD:

- Supervivencia de 20 minutos.
- Jefe final al terminar el tiempo.
- Enemigos/minijefes con ataques especiales.
- Armas steampunk como llave boomerang, rayos o variantes por personaje.

## Estado actual de sistemas implementados

Esta seccion resume el rediseño mas reciente para tener una foto rapida del juego actual y de donde balancear cada mecanica.

### Flujo de pantallas

El flujo actual es:

```text
Menu principal -> Seleccion de personaje -> Level 1 -> Partida -> Menu de muerte
```

- `Scenes/Menu.tscn`: muestra iniciar partida y salir.
- `Scenes/CharacterSelectMenu.tscn`: permite elegir entre los 3 personajes del atlas `personajes.png`.
- `Scenes/Nivel1/level_1.tscn`: inicia la partida.
- `Scenes/DeathMenu.tscn`: aparece al morir con el texto `LA MUERTE HA ENCONTRADO` y permite volver al menu.

El menu principal, seleccion de personaje y menu de mejoras usan decoracion steampunk de pergamino y engranajes mediante `Assets/Scripts/gear_decoration.gd`.

### Personajes y armas iniciales

El personaje elegido se guarda en `Global.selected_character_id` y cambia el sprite del `Player` recortando `personajes.png`.

Armas iniciales por personaje:

- Ingeniero, indice `0`: empieza con `ShotgunWeapon`.
- Mecanico, indice `1`: empieza con `AxeWeapon`.
- Soldador, indice `2`: empieza con `LaserWeapon`.

El jugador puede tener hasta `MAX_WEAPON_SLOTS = 2` armas activas.

### Sistema de armas actual

Todas las armas heredan de `Weapon.gd`. El player llama cada frame:

```gdscript
weapon.tick(delta, self, stats)
```

`Weapon.tick()` baja el cooldown y, si llega a cero, llama `try_attack()`.

Formula general de cooldown:

```gdscript
if use_player_fire_rate:
	cooldown = 1.0 / (stats.current_fire_rate * fire_rate_multiplier)
else:
	cooldown = cooldown_seconds
```

#### Shotgun

Archivo: `Assets/Scripts/shotgun_weapon.gd`

Hereda de `ProjectileWeapon`. Dispara proyectiles rectos y prioriza al enemigo mas cercano dentro del rango. Si no hay enemigos cerca, dispara en direccion de movimiento; si el player esta quieto, usa una direccion rotativa para que no quede inactiva.

Variables para balancear:

- `cooldown_seconds = 1.0`: cooldown base.
- Mejora `SHOTGUN_FIRE_RATE`: baja cooldown a `0.7`.
- `spread_degrees`: apertura entre proyectiles.
- `extra_projectiles`: balas extra.
- `damage_multiplier`: multiplica el daño final del arma.

Formula de daño:

```gdscript
damage = stats.current_attack * damage_multiplier
```

Mejoras secuenciales:

1. `SHOTGUN_EXTRA_PROJECTILE`: +1 bala.
2. `SHOTGUN_FIRE_RATE`: cooldown 0.7s.
3. `SHOTGUN_DAMAGE`: +25% daño de shotgun.

#### Laser

Archivo: `Assets/Scripts/laser_weapon.gd`

Dispara una recta desde la boca del arma hasta el rango maximo. Igual que la shotgun, prioriza al enemigo mas cercano si existe. Si no hay enemigos cerca, dispara en una direccion libre: perpendicular al movimiento o rotativa si el player esta quieto.

Variables para balancear:

- `cooldown_seconds = 1.0`: cooldown base.
- `beam_count`: cantidad de rayos.
- `beam_width`: ancho de deteccion del rayo.
- `base_damage_multiplier = 0.85`: daño base relativo al ataque del player.
- `range_multiplier`: multiplica `stats.current_weapon_range`.
- `piercing`: si esta activo, daña a todos los enemigos sobre la recta.

Formula de daño:

```gdscript
damage = stats.current_attack * base_damage_multiplier * damage_multiplier
```

Mejoras secuenciales:

1. `LASER_EXTRA_BEAM`: dispara 2 rayos.
2. `LASER_PIERCING`: atraviesa enemigos.
3. `LASER_DAMAGE`: +25% daño de laser.

Visualmente usa `LaserBeamEffect`: dibuja una canalizacion circular celeste en el punto A y una linea hacia B que se desvanece desde A hacia B.

#### Hacha orbital

Archivo: `Assets/Scripts/axe_weapon.gd`

Cada activacion crea un `AxeOrbitEffect` que gira alrededor del player, golpea enemigos dentro del radio y cada enemigo solo recibe daño una vez por activacion.

Variables para balancear:

- `cooldown_seconds = 2.6`: cooldown base actual.
- Mejora `AXE_COOLDOWN`: baja cooldown a `1.2`.
- `radius = 112.0`: radio de giro. El diametro real visual es `radius * 2`.
- `effect_duration = 0.75`: tiempo durante el cual el hacha gira y puede golpear.
- `axe_count`: cantidad de hachas simultaneas.
- `base_damage_multiplier = 0.9`: daño base relativo al ataque del player.
- `damage_multiplier`: multiplicador por mejoras.

Formula de daño:

```gdscript
damage = stats.current_attack * base_damage_multiplier * damage_multiplier
```

Mejoras secuenciales:

1. `AXE_COOLDOWN`: cooldown 1.2s.
2. `AXE_EXTRA_AXE`: +1 hacha.
3. `AXE_DAMAGE`: +25% daño de hacha.

Para alejar o acercar el hacha del player, modificar `radius` en `AxeWeapon`. Si se instancia por codigo, el valor default vive en `Assets/Scripts/axe_weapon.gd`.

### Sistema de mejoras actual

El menu de nivel ofrece 3 opciones aleatorias. La lista puede incluir:

- Mejoras de personaje.
- Desbloqueos de arma.
- Mejoras del arma que ya se tiene.

Reglas importantes:

- Maximo `MAX_ACTIVE_UPGRADE_STATS = 4` tipos de mejoras de personaje por partida.
- Cada mejora de personaje puede elegirse hasta `MAX_UPGRADE_STACKS_PER_STAT = 3` veces.
- Las armas no consumen esos 4 espacios de mejoras de personaje.
- Las mejoras de arma son secuenciales por arma.
- El jugador puede tener hasta 2 armas activas.

Mejoras de personaje actuales:

- `MAX_HEALTH`: vida maxima plana y cura al maximo despues de aplicarse.
- `MOVE_SPEED`: velocidad de movimiento porcentual.
- `PICKUP_RANGE`: rango magnetico de gemas.
- `DAMAGE_REDUCTION`: reduccion porcentual global de daño.
- `SHIELD`: bloquea 1 golpe y entra en cooldown.
- `HEALTH_REGEN`: regeneracion de vida por segundo.

La mejora de regeneracion se aplica cada frame:

```gdscript
stats.health += stats.current_health_regen * delta
```

El escudo usa estos cooldowns:

```text
nivel 1: 60s
nivel 2: 45s
nivel 3: 30s
```

### Caps de balance actuales

Archivo: `Assets/Scripts/Stats.gd`

Constantes:

```gdscript
MAX_NATURAL_HEALTH = 150.0
MAX_DEFENSE = 100.0
MAX_ATTACK_WITHOUT_UPGRADE = 200.0
```

Reglas:

- La vida maxima natural por nivel no pasa de `150`.
- La mejora `MAX_HEALTH` puede superar ese limite.
- La defensa actual no puede superar `100`.
- El ataque natural no puede superar `200`.
- Una mejora global de `ATTACK`, si se vuelve a agregar al pool, permite superar el cap de `200`.
- Las mejoras de daño de armas multiplican el daño despues de `current_attack`, asi que pueden hacer que el daño real de un arma supere 200.

### Formula de experiencia

Archivo: `Assets/Scripts/Stats.gd`

Nivel actual:

```gdscript
level = floor(max(1.0, sqrt(experience / BASE_LEVEL_EXP) + 0.5))
```

Experiencia total requerida para un nivel:

```gdscript
normalized_level = max(target_level, 1) - 0.5
required_exp = normalized_level * normalized_level * BASE_LEVEL_EXP
```

Con `BASE_LEVEL_EXP = 100`, cada nivel pide mas experiencia que el anterior.

### Formula de daño recibido

Archivo: `Assets/Scripts/Stats.gd`

El daño final se calcula asi:

```gdscript
percent_reduction = clamp(current_damage_reduction + resistance_by_type, 0.0, 0.95)
effective_defense = current_defense * (1.0 - defense_penetration)
defense_reduction = effective_defense / (effective_defense + DEFENSE_REDUCTION_SCALE)
defense_reduction = clamp(defense_reduction, 0.0, MAX_DEFENSE_REDUCTION)
final_damage = raw_damage * (1.0 - percent_reduction) * (1.0 - defense_reduction)
final_damage = max(final_damage, 1.0)
```

Valores actuales:

```gdscript
DEFENSE_REDUCTION_SCALE = 300.0
MAX_DEFENSE_REDUCTION = 0.65
```

Para que la defensa reduzca menos daño, subir `DEFENSE_REDUCTION_SCALE`.
Para que la defensa reduzca mas daño, bajar `DEFENSE_REDUCTION_SCALE`.
Para limitar el techo de reduccion por defensa, modificar `MAX_DEFENSE_REDUCTION`.

### Spawner y dificultad

Archivo: `Assets/Scripts/spawn.gd`

Variables principales:

- `base_wait_time = 1.2`: tiempo inicial entre oleadas.
- `min_wait_time = 0.2`: tiempo minimo entre oleadas.
- `wait_time_decrease_per_minute = 0.25`: cuanto baja el timer por minuto.
- `extra_enemy_per_minute = 1`: enemigos extra por minuto.
- `enemy_health_growth_per_minute = 0.25`: crecimiento de vida enemigo por minuto.
- `enemy_damage_growth_per_minute = 0.15`: crecimiento de daño enemigo por minuto.
- `spawn_outside_camera = true`: spawnea fuera de camara.
- `boss_spawn_interval_seconds = 300.0`: jefe cada 5 minutos.
- `drone_wave_interval_seconds = 30.0`: oleada de drones cada 30 segundos.
- `drone_wave_count = 4`: cantidad de drones por oleada.
- `sphere_miniboss_first_spawn_seconds = 60.0`: primera aparicion del minijefe esfera al minuto 1.
- `sphere_miniboss_interval_seconds = 40.0`: frecuencia posterior del minijefe esfera.

Formulas:

```gdscript
minutes = Global.survived_time / 60.0
amount = 1 + floor(minutes * extra_enemy_per_minute)
enemy.max_health *= 1.0 + minutes * enemy_health_growth_per_minute
enemy.damage *= 1.0 + minutes * enemy_damage_growth_per_minute
enemy.experience_value *= 1.0 + minutes * 0.1
timer.wait_time = max(min_wait_time, base_wait_time - minutes * wait_time_decrease_per_minute)
```

Para que haya menos enemigos:

- Subir `base_wait_time`.
- Subir `min_wait_time`.
- Bajar `wait_time_decrease_per_minute`.
- Bajar `extra_enemy_per_minute`.

Para que los enemigos escalen mas lento:

- Bajar `enemy_health_growth_per_minute`.
- Bajar `enemy_damage_growth_per_minute`.

### Oleada de drones

Archivo de escena: `Scenes/DroneEnemy.tscn`

Cada `drone_wave_interval_seconds` segundos, el spawner crea una bandada de `drone_wave_count` drones usando `Assets/Images/Enemigo_Dron.png`.

Comportamiento:

- Aparecen en una esquina aleatoria fuera de camara.
- Se mueven en diagonal hacia la esquina opuesta.
- La ruta posible es A -> D, B -> C, C -> B o D -> A.
- Si pasan por encima del player, aplican daño.
- Si el player los mata, dropean gema porque heredan de `Enemy`.
- Si llegan al destino, desaparecen y no dropean gema.

Variables para balancear:

- `drone_wave_interval_seconds`: cada cuanto aparece una oleada.
- `drone_wave_count`: cantidad de drones.
- `drone_wave_spacing`: separacion lateral entre drones.
- `drone_spawn_margin`: distancia extra fuera de camara.
- `drone_health_growth_per_minute`: escalado de vida.
- `drone_damage_growth_per_minute`: escalado de daño.

### Minijefe esfera

Archivos:

- `Scenes/SphereMiniBoss.tscn`
- `Assets/Scripts/sphere_miniboss.gd`

El minijefe esfera usa `Assets/Images/Enemigo_esfera.png`. Aparece por primera vez en `sphere_miniboss_first_spawn_seconds` y luego cada `sphere_miniboss_interval_seconds`.

Comportamiento:

- Tiene mas vida y experiencia que un enemigo comun.
- Intenta mantenerse a media distancia del player.
- Cuando el player esta en rango, fija una direccion de disparo hacia la posicion actual del player.
- Primero muestra una linea roja de advertencia durante `laser_warning_time`.
- Despues dispara un rayo electrico breve sobre esa misma linea.
- Como la direccion queda bloqueada al iniciar la advertencia, el player tiene tiempo de esquivar.
- Si muere, dropea gema como cualquier enemigo.

Variables para balancear en `SphereMiniBoss.tscn` o `sphere_miniboss.gd`:

- `speed`: velocidad de movimiento.
- `max_health`: vida base.
- `experience_value`: experiencia de la gema al morir.
- `preferred_distance`: distancia que intenta mantener.
- `laser_range`: alcance del rayo.
- `laser_width`: ancho del rayo y margen de impacto.
- `laser_warning_time`: tiempo de aviso antes del daño.
- `laser_active_time`: duracion visible del rayo.
- `laser_cooldown`: recarga entre disparos.
- `laser_damage`: daño del rayo.
- `defense_penetration`: porcentaje de defensa ignorada.

### BossRobot

Archivo de escena: `Scenes/BossRobot.tscn`

El boss aparece cada `boss_spawn_interval_seconds` segundos. Mientras esta vivo, el spawner deja de crear enemigos normales. Cuando muere, el spawner calcula el proximo bloque de boss y reanuda la oleada normal.

Stats actuales del boss:

- `speed = 70.0`
- `max_health = 2000.0`
- `experience_value = 350.0`
- `damage = 100`
- `defense_penetration = 0.75`
- `AttackTimer.wait_time = 1.2`

Para hacerlo mas amenazante:

- Subir `damage`.
- Subir `defense_penetration`.
- Bajar `AttackTimer.wait_time`.
- Subir `speed` con cuidado, porque la fantasia actual es que sea lento pero peligroso.

El sprite del boss ahora usa `Assets/Images/Enemigo_RobotGordo.png`, con fondo transparente y escala ajustada en `Scenes/BossRobot.tscn`.

### HUD, pausa y debug

HUD:

- Barra de experiencia superior.
- Nivel arriba a la izquierda.
- Barra de vida debajo del player.
- Tiempo sobrevivido.
- Contador de enemigos derrotados.

Pausa:

- `Escape` o `Enter` abre un panel lateral.
- Muestra stats actuales y hasta 4 mejoras de personaje con nivel `actual/3`.

Debug:

- Se activa con `.env` o variable de entorno `SIGLO21_DEBUG=1`.
- Muestra numeros exactos de experiencia.
- Habilita logs mediante `Global.debug_log()`.

### Audio

Archivo: `Assets/Scripts/audio_manager.gd`

`AudioManager` esta registrado como autoload en `project.godot`, por eso existe durante todo el juego y no se reinicia al cambiar de escena.

Sonidos actuales:

- `Assets/Sounds/game-start.mp3`: suena una sola vez al abrir el juego.
- `Assets/Sounds/music-sound.mp3`: musica de fondo en loop.
- `Assets/Sounds/button-ui-sound.mp3`: suena al enfocar, pasar el mouse o presionar botones UI.
- `Assets/Sounds/game-over.mp3`: suena cuando muere el player.
- `Assets/Sounds/levelup-sound.mp3`: suena cuando aparece el menu de mejora.
- `Assets/Sounds/shotgun-sound.mp3`: suena cada vez que dispara la shotgun.

Volumenes para balancear:

```gdscript
MUSIC_VOLUME_DB = -16.0
SFX_VOLUME_DB = -2.0
UI_VOLUME_DB = -8.0
SHOTGUN_VOLUME_DB = -5.0
```

La musica queda mas baja que los efectos. Para subirla, acercar `MUSIC_VOLUME_DB` a `0`. Para bajarla, usar valores mas negativos.

El sonido de UI tiene un cooldown corto:

```gdscript
UI_SOUND_COOLDOWN_SECONDS = 0.05
```

Esto evita que mouse hover y click disparen demasiados sonidos juntos.

## Estructura importante

### Scripts

- `Assets/Scripts/Stats.gd`: recurso de estadisticas, vida, experiencia, nivel y buffs.
- `Assets/Scripts/stat_buff.gd`: recurso que representa una mejora aplicada a un stat.
- `Assets/Scripts/player.gd`: movimiento, disparo, daño recibido, experiencia y level up del jugador.
- `Assets/Scripts/enemy.gd`: clase base para enemigos, vida, daño recibido, muerte y drop de gemas.
- `Assets/Scripts/miniboss_enemy.gd`: clase base para minijefes con ataque especial.
- `Assets/Scripts/boss_enemy.gd`: clase base para jefes con fases.
- `Assets/Scripts/boss_robot.gd`: jefe robot lento, resistente y de mucho daño.
- `Assets/Scripts/drone_enemy.gd`: enemigo dron de oleadas diagonales.
- `Assets/Scripts/sphere_miniboss.gd`: minijefe esfera con rayo telegrafiado.
- `enemigo1.gd`: IA especifica del enemigo BabyAllien, movimiento y ataque al jugador.
- `Assets/Scripts/weapon.gd`: clase base de armas.
- `Assets/Scripts/projectile_weapon.gd`: arma de proyectiles usada por el player.
- `Assets/Scripts/shotgun_weapon.gd`: arma inicial del ingeniero, basada en proyectiles.
- `Assets/Scripts/laser_weapon.gd`: arma laser desbloqueable por mejora epica.
- `Assets/Scripts/laser_beam_effect.gd`: efecto visual de canalizacion y barrido del laser.
- `Assets/Scripts/axe_weapon.gd`: arma orbital inicial del mecanico.
- `Assets/Scripts/axe_orbit_effect.gd`: efecto visual y daño del hacha orbital.
- `Assets/Scripts/bullet_example.gd`: proyectil que viaja recto y daña enemigos.
- `Assets/Scripts/gema.gd`: gema recolectable que entrega experiencia.
- `Assets/Scripts/spawn.gd`: spawner de enemigos.
- `Assets/Scripts/upgrade_menu.gd`: menu de seleccion de mejoras al subir de nivel.
- `Assets/Scripts/hud.gd`: HUD de vida, experiencia y nivel.
- `Assets/Scripts/Global.gd`: singleton/autoload con referencia global al jugador.

### Escenas

- `Scenes/Nivel1/level_1.tscn`: escena principal del nivel.
- `Scenes/Player.tscn`: escena del jugador.
- `Scenes/enemigo1.tscn`: escena del enemigo `BabyAllien`.
- `Scenes/BossRobot.tscn`: escena del jefe robot.
- `Scenes/DroneEnemy.tscn`: escena del dron de oleadas diagonales.
- `Scenes/SphereMiniBoss.tscn`: escena del minijefe esfera.
- `Scenes/bullet_example.tscn`: escena del proyectil.
- `Scenes/Gema.tscn`: escena de la gema de experiencia.
- `Scenes/UpgradeMenu.tscn`: escena del menu de mejoras.
- `Scenes/HUD.tscn`: escena de interfaz durante la partida.
- `Scenes/Menu.tscn`: menu existente del proyecto.
- `Scenes/CharacterSelectMenu.tscn`: seleccion de personaje antes de iniciar la partida.

### Recursos

- `Assets/Resources/Player_stats.tres`: stats base del jugador.
- `Assets/Resources/maxHealth_statCurve.tres`: curva de vida maxima por nivel.
- `Assets/Resources/defense_statCurve.tres`: curva de defensa por nivel.
- `Assets/Resources/attack_statCurve.tres`: curva de ataque por nivel.

## Sistema de stats

Archivo: `Assets/Scripts/Stats.gd`

`Stats` es un `Resource`, no un nodo de escena. Esto permite crear recursos `.tres` editables desde el inspector de Godot.

Define estos stats:

- `base_max_health`: vida maxima base.
- `base_defense`: defensa base.
- `base_attack`: ataque base.
- `base_move_speed`: velocidad base de movimiento.
- `base_fire_rate`: disparos por segundo base.
- `experience`: experiencia acumulada.
- `level`: nivel calculado automaticamente desde la experiencia.
- `current_max_health`: vida maxima actual, despues de curvas y buffs.
- `current_defense`: defensa actual.
- `current_attack`: ataque actual.
- `current_move_speed`: velocidad actual del jugador.
- `current_fire_rate`: disparos por segundo actuales.
- `health`: vida actual.

### Nivel y experiencia

El nivel se calcula con:

```gdscript
floor(max(1.0, sqrt(experience / BASE_LEVEL_EXP) + 0.5))
```

Esto significa que el crecimiento de experiencia es progresivo: cada nivel requiere mas experiencia que el anterior.

Funciones utiles:

- `add_experience(amount)`: suma experiencia.
- `get_experience_for_level(target_level)`: devuelve cuanta experiencia total pide un nivel.
- `get_experience_to_next_level()`: devuelve cuanta experiencia falta para subir.
- `on_experience_set(new_value)`: setter de `experience`; detecta si subio el nivel.

Cuando el nivel cambia:

1. Recalcula stats.
2. Cura al jugador al maximo.
3. Emite `leveled_up(new_level, old_level)`.

### Vida

La vida se guarda en `health`.

Cuando cambia `health`, se llama a `_on_health_set()`:

- Limita la vida entre `0` y `current_max_health`.
- Emite `health_changed`.
- Si llega a `0`, emite `health_depleted`.

Esto permite conectar UI de barra de vida o logica de muerte sin duplicar codigo.

### Daño y defensa

El daño al jugador se centraliza en `Stats.take_damage(raw_damage)`.

Flujo:

1. Recibe daño bruto.
2. Calcula daño final con `get_damage_after_defense()`.
3. Resta el daño final a `health`.
4. Emite `damage_taken(raw_damage, final_damage)`.
5. Devuelve el daño final aplicado.

Actualmente la defensa reduce daño con una curva porcentual suave:

```gdscript
defense_reduction = defense / (defense + 300)
final_damage = raw_damage * (1.0 - damage_reduction) * (1.0 - defense_reduction)
```

Eso hace que la defensa ayude sin anular completamente golpes medianos. Por ejemplo, `34.7` de defensa reduce cerca de 10%, y `119` reduce cerca de 28%. La reduccion maxima por defensa queda limitada por `MAX_DEFENSE_REDUCTION`.

El sistema actual tambien soporta reduccion porcentual global, resistencias por tipo de daño (`PHYSICAL`, `ELECTRIC`, `FIRE`), invulnerabilidad breve con `set_invulnerable()`, y señales de feedback como `damage_taken` y `damage_blocked`.

`take_damage()` tambien acepta `defense_penetration`. Un valor de `0.75` hace que el golpe ignore el 75% de la defensa plana del objetivo. Esto se usa para jefes, asi la defensa alta no convierte sus ataques en daño minimo.

### Curvas de stats

`Stats.gd` usa `STAT_CURVES` para modificar los stats segun el nivel.

La funcion `_get_curve_multiplier()` normaliza las curvas para que en nivel 1 el multiplicador sea `1.0`. Gracias a eso, si `base_max_health` es `5`, la vida en nivel 1 empieza en `5` y no en un valor inflado por la curva.

Para modificar el escalado:

1. Abrir una curva en `Assets/Resources`.
2. Cambiar sus puntos desde el editor.
3. Probar como cambia el stat al subir de nivel.

## Sistema de buffs/mejoras

Archivo: `Assets/Scripts/stat_buff.gd`

`StatBuff` es un `Resource` simple que representa una mejora.

Campos:

- `stat`: stat afectado. Usa `Stats.BuffableStats`.
- `buff_amount`: cantidad del buff.
- `buff_type`: tipo de buff.

Tipos disponibles:

- `ADD`: suma un valor plano. Ejemplo: `+15 vida maxima`.
- `MULTIPLY`: suma un multiplicador. Ejemplo: `+0.15 ataque` equivale a `+15%`.

Ejemplo:

```gdscript
StatBuff.new(Stats.BuffableStats.ATTACK, 0.15, StatBuff.BuffType.MULTIPLY)
```

Ese buff aumenta el ataque actual en 15%.

### Como se aplican

`Stats.add_buff(buff)` agrega el buff a `stat_buffs` y recalcula stats.

`Stats.recalculate_stats()`:

1. Calcula stats base escalados por curva.
2. Aplica multiplicadores.
3. Aplica sumas planas.

Para agregar nuevos stats modificables:

1. Agregar el stat al enum `BuffableStats`.
2. Agregar una variable base, por ejemplo `base_speed`.
3. Agregar una variable actual, por ejemplo `current_speed`.
4. Agregar su curva a `STAT_CURVES`.
5. Usar el nombre siguiendo el patron `current_` + nombre del enum en minuscula.

## Player

Archivo: `Assets/Scripts/player.gd`

El `Player` extiende `CharacterBody2D` y tiene `class_name Player`, lo que permite usarlo como tipo en otros scripts.

Responsabilidades:

- Guardar referencia global en `Global.Player`.
- Moverse con inputs.
- Buscar enemigos cercanos.
- Disparar automaticamente.
- Recibir daño.
- Recibir experiencia.
- Generar mejoras al subir de nivel.
- Abrir el menu de mejoras.

### Movimiento

En `_physics_process()` usa:

```gdscript
Input.get_vector("izquierda", "derecha", "arriba", "abajo")
```

Los inputs estan definidos en `project.godot`:

- `W`: arriba.
- `S`: abajo.
- `A`: izquierda.
- `D`: derecha.

La direccion se multiplica por `speed` y luego se llama `move_and_slide()`.

### Sistema de armas

El `Player` puede tener hasta 2 armas activas y llama `weapon.tick(delta, self, stats)` en cada frame. Las armas iniciales por personaje son: ingeniero con `ShotgunWeapon`, mecanico con `AxeWeapon` y soldador con `LaserWeapon`.

La shotgun sigue esta logica interna:

1. Toma los cuerpos dentro del `Area2D` del jugador.
2. Filtra los que estan en grupo `"Enemy"`.
3. Busca el enemigo mas cercano.
4. Rota el arma con `look_at()`.
5. Instancia una bala.
6. La agrega al padre del jugador, normalmente el nivel.
7. Llama `launch()` en la bala.
8. Le pasa el daño desde `stats.current_attack`.

La bala se agrega al nivel y no al jugador para evitar que herede el movimiento del jugador. Si se agregara como hija del jugador, pareceria curvarse al moverse el player.

`ShotgunWeapon` hereda de `ProjectileWeapon`: busca el enemigo mas cercano, instancia balas y puede mejorar bala extra, cadencia y daño.

`LaserWeapon` dispara una recta desde A hacia B. Sus mejoras son:

1. Rayo extra.
2. Agrega piercing para dañar a todos los enemigos en la recta.
3. Aumenta el daño del laser en 25%.

Visualmente usa `LaserBeamEffect`: primero dibuja una canalizacion circular celeste en el punto A, luego muestra una linea hacia B y la hace desaparecer desde A hacia B.

`AxeWeapon` crea un `AxeOrbitEffect` cada cierto cooldown. El hacha gira alrededor del jugador, golpea enemigos cercanos una vez por activacion y puede mejorar cooldown, hacha extra y daño.

### Recibir experiencia

`add_experience(amount)` delega en:

```gdscript
stats.add_experience(amount)
```

Tambien imprime experiencia, nivel y experiencia faltante para debug.

Este metodo es usado por la gema. La gema no necesita saber que el cuerpo es exactamente `Player`; solo revisa si tiene `add_experience()`.

### Subir de nivel

Cuando `Stats` emite `leveled_up`, el player ejecuta `_on_stats_leveled_up()`.

Flujo:

1. Encola cada nivel ganado en `pending_upgrade_levels`.
2. Crea hasta 3 opciones con `_build_upgrade_choices(new_level)`.
3. Guarda las opciones en `pending_upgrade_choices`.
4. Emite `upgrade_choices_ready`.
5. Instancia `Scenes/UpgradeMenu.tscn`.
6. Mantiene el juego pausado hasta elegir.

Mejoras actuales de personaje:

- Vida maxima plana.
- Velocidad de movimiento porcentual.
- Rango magnetico de gemas.
- Reduccion porcentual de daño.
- Escudo de emergencia.
- Regeneracion de vida por segundo.

Tambien pueden aparecer desbloqueos de arma y mejoras del arma ya equipada. Para modificar el pool de personaje, editar `_build_character_upgrade_pool()`. Para armas, editar `_build_weapon_unlock_pool()` y `_get_next_weapon_upgrade()`.

Actualmente se conserva el pool completo de mejoras y se eligen 3 opciones al azar con `shuffle()`. Esto evita que las opciones sean siempre las mismas.

Durante una partida, el jugador puede especializarse en un maximo de 4 stats distintos. Cada stat elegido tiene un limite temporal de 3 elecciones. Cuando un stat llega a ese limite, deja de aparecer en el pool; cuando ya hay 4 stats distintos elegidos, el menu solo ofrece mejoras de esos stats hasta que se agoten.

Si el jugador sube varios niveles de golpe, las pantallas de mejora se encolan: solo puede haber un menu activo, el juego permanece pausado, y al elegir una mejora aparece la siguiente seleccion pendiente.

### Elegir mejora

`choose_upgrade(choice_index)`:

1. Valida que el indice exista.
2. Registra el stack elegido en `upgrade_counts_by_stat`.
3. Si es desbloqueo o mejora de arma, llama `_apply_weapon_upgrade()`.
4. Si es escudo, llama `_apply_shield_upgrade()`.
5. Si es stat normal, aplica el buff con `stats.add_buff()`.
6. Limpia `pending_upgrade_choices`.
7. Si habia otros niveles pendientes, abre el siguiente menu.

El menu llama esta funcion cuando el jugador elige una opcion.

Si la mejora elegida afecta `MAX_HEALTH`, `Player` pide que `Stats` cure al maximo despues de recalcular. Asi el jugador queda con la nueva vida maxima, incluyendo la mejora.

### Recibir daño

`TakeDamage(damage)`:

1. Verifica que existan stats.
2. Reinicia la particula `CPUParticles2D`.
3. Llama `stats.take_damage()`.
4. El calculo de defensa ocurre dentro de `Stats`.
5. Si la vida llega a 0, llama `Die()`.

`Die()` elimina al player con `queue_free()`.

Los logs de daño solo aparecen si el modo debug esta activo.

## Clase base Enemy

Archivo: `Assets/Scripts/enemy.gd`

`Enemy` extiende `CharacterBody2D` y concentra la logica compartida por enemigos.

Variables exportadas:

- `speed`: velocidad de movimiento.
- `max_health`: vida maxima.
- `experience_value`: experiencia que dara la gema al morir.
- `gem_scene`: escena de la gema que dropea.
- `drop_gem_chance`: probabilidad de soltar gema.
- `damage`: daño que aplica al jugador.
- `stats`: recurso opcional para enemigos con stats propios.
- `phase_health_ratios`: umbrales de fase para jefes o enemigos especiales.

Responsabilidades:

- Agregarse al grupo `"Enemy"`.
- Inicializar `health`.
- Recibir daño con `TakeDamage()`.
- Morir con `_die()`.
- Soltar gema con `_drop_gem()`.

Para crear un enemigo nuevo, heredar de `Enemy` y escribir solo su comportamiento particular.

Tambien hay clases listas para escenas futuras: `MiniBossEnemy` agrega ataque especial con cooldown, y `BossEnemy` usa fases para escalar daño y velocidad.

## Enemigo BabyAllien

Archivo: `enemigo1.gd`

`BabyAllien` hereda de `Enemy` y tiene `class_name BabyAllien`.

### Movimiento y ataque

En `_physics_process()`:

- Si `Global.Player` es `null`, no hace nada.
- Si `canAttack` es `true`, llama `Attack()`.
- Si no, llama `Move()`.

`Move()` calcula direccion hacia el player y se mueve con `move_and_slide()`.

`Attack()`:

1. Revisa si el timer esta en cooldown.
2. Llama `Global.Player.TakeDamage(damage)`.
3. Reinicia el timer.

`canAttack` cambia segun el `Area2D` del enemigo:

- `_on_area_2d_body_entered()`: si entra el player, puede atacar.
- `_on_area_2d_body_exited()`: si sale el player, deja de atacar.

### Recibir daño y morir

BabyAllien hereda `TakeDamage()`, `_die()` y `_drop_gem()` desde `Enemy`.

Para crear enemigos nuevos:

1. Crear una nueva escena parecida a `enemigo1.tscn`.
2. Crear un script que haga `extends Enemy`.
3. Ajustar `speed`, `max_health`, `damage` y `experience_value`.
4. Cambiar el preload en `spawn.gd` si queres que el spawner use ese enemigo.

## Bala/proyectil

Archivo: `Assets/Scripts/bullet_example.gd`

La bala extiende `CharacterBody2D`.

Variables:

- `Direction`: direccion fija del disparo.
- `speedBullet`: velocidad.
- `damageAmount`: daño que aplicara.

### Launch

`launch(start_position, target_position, attack_damage)` inicializa la bala:

1. Posiciona la bala en `start_position`.
2. Calcula una direccion hacia `target_position`.
3. Guarda el daño recibido desde el player.
4. Rota la bala para mirar hacia la direccion.

Despues de eso, la bala ya no sigue al enemigo. Sigue una trayectoria recta.

### Movimiento

En `_physics_process()`:

```gdscript
velocity = Direction.normalized() * speedBullet
move_and_slide()
```

### Impacto

Cuando su `Area2D` detecta un cuerpo:

- Si esta en grupo `"Enemy"`, llama `body.TakeDamage(damageAmount)`.
- Luego se destruye con `queue_free()`.

El `Timer` de la escena destruye la bala despues de 3 segundos para evitar balas infinitas.

Mejoras posibles:

- Usar `Area2D` como raiz en vez de `CharacterBody2D`, si la bala no necesita fisica de cuerpo.
- Agregar pierce, criticos o knockback.
- Agregar collision layers diferentes para no golpear cosas no deseadas.

## Gema de experiencia

Archivo: `Assets/Scripts/gema.gd`

La gema extiende `Area2D`.

Variable:

- `experience_amount`: experiencia que entrega al recolectarse.

En `_ready()` conecta su señal `body_entered` a `_on_body_entered()`.

Cuando un cuerpo entra:

1. Revisa si el cuerpo tiene metodo `add_experience`.
2. Si lo tiene, llama `body.add_experience(experience_amount)`.
3. Se elimina con `queue_free()`.

La escena `Scenes/Gema.tscn` tiene:

- Root `Area2D`.
- `collision_mask = 4`, para detectar al player.
- `CollisionShape2D` para la zona de recoleccion.

Para cambiar cuanta experiencia da:

- Cambiar `experience_value` en el enemigo.
- O cambiar `experience_amount` por defecto en la gema.

La gema ahora tiene recoleccion magnetica: si el player esta dentro de `stats.current_pickup_range`, se mueve hacia el personaje usando `attraction_speed`.

## Menu de mejoras

Archivos:

- `Assets/Scripts/upgrade_menu.gd`
- `Scenes/UpgradeMenu.tscn`

El menu se instancia cuando el player sube de nivel.

### Pausa

En `_ready()`:

```gdscript
process_mode = Node.PROCESS_MODE_ALWAYS
get_tree().paused = true
```

Esto pausa el juego, pero permite que el menu siga recibiendo input.

Cuando se elige una mejora:

```gdscript
get_tree().paused = false
queue_free()
```

### Setup

`setup(_player, _choices, level)` recibe:

- El player que debe recibir la mejora.
- La lista de 3 buffs.
- El nivel nuevo para mostrar en pantalla.

### Controles

Se puede elegir con:

- Click del mouse.
- `ui_up` y `ui_down` para cambiar opcion enfocada.
- `ui_accept`, `Enter` o `Space` para confirmar.

Nota: Godot ya trae acciones `ui_up`, `ui_down` y `ui_accept` por defecto. En este proyecto tambien hay una accion `enter`, pero el menu usa `ui_accept` y chequeo directo de `KEY_ENTER`/`KEY_SPACE`.

### Texto de las opciones

`_get_choice_text(choice)` convierte un `StatBuff` en texto:

- `ADD`: `+15 MAX HEALTH`.
- `MULTIPLY`: `+15% ATTACK`.

Para cambiar el estilo visual, editar `Scenes/UpgradeMenu.tscn`.

Para cambiar nombres mas lindos, editar `_get_choice_text()`.

## Menu de pausa y muerte

Archivos:

- `Assets/Scripts/pause_menu.gd`
- `Scenes/PauseMenu.tscn`
- `Assets/Scripts/death_menu.gd`
- `Scenes/DeathMenu.tscn`

Durante la partida, `Player.gd` escucha `Escape` y `Enter`. Si no hay menu de mejoras activo, instancia `PauseMenu.tscn`, pausa el arbol y muestra un panel lateral izquierdo.

El panel de pausa muestra hasta 4 espacios de mejoras. Esos espacios se llenan con los stats distintos que el jugador eligio durante la partida y cada uno se muestra en formato `actual/3`. Si todavia no se eligieron 4 tipos distintos, los espacios restantes aparecen vacios.

Si la vida llega a 0, `Player.Die()` detiene la run, limpia UI persistente agregada al root y carga `Scenes/DeathMenu.tscn`. Esa pantalla muestra `LA MUERTE HA ENCONTRADO` y un boton `Volver` que regresa a `Scenes/Menu.tscn`.

## HUD de partida

Archivos:

- `Assets/Scripts/hud.gd`
- `Scenes/HUD.tscn`
- `Scenes/Player.tscn`

El HUD muestra informacion importante durante la partida:

- Barra de experiencia arriba de la pantalla.
- Texto de nivel en la esquina superior izquierda.
- Barra de vida debajo del personaje.
- Tiempo sobrevivido.
- Contador de enemigos derrotados.

### Barra de vida del player

La barra de vida es un `ProgressBar` llamado `HealthBar` dentro de `Scenes/Player.tscn`.

`Player.gd` se conecta a:

```gdscript
stats.health_changed.connect(_on_stats_health_changed)
```

Cada vez que cambia la vida, `_update_health_bar()` ajusta:

- `health_bar.max_value`
- `health_bar.value`

Como la barra es hija del player, se mueve junto con el personaje.

### Barra de experiencia y nivel

`Player.gd` instancia `Scenes/HUD.tscn` al iniciar:

```gdscript
_show_hud.call_deferred()
```

El HUD recibe el recurso `Stats` con `setup(stats)`.

`hud.gd` se conecta a:

- `stats.experience_changed`
- `stats.leveled_up`

La barra de experiencia usa:

- `get_current_level_experience()`
- `get_next_level_required_experience()`

El texto de nivel usa:

```gdscript
stats.level
```

Los numeros de experiencia (`0 / 225 XP`) solo se muestran si el modo debug esta activo.

Para cambiar posicion, colores o tamano del HUD, editar `Scenes/HUD.tscn`.

## Modo debug

El modo debug se activa con la variable de entorno:

```text
SIGLO21_DEBUG=1
```

Valores aceptados:

- `1`
- `true`
- `yes`
- `on`

`Global.gd` lee esta variable al iniciar y guarda el resultado en `Global.debug_enabled`.

Para escribir mensajes de debug se usa:

```gdscript
Global.debug_log("mensaje")
```

Si debug esta apagado, no imprime nada.

Actualmente el modo debug:

- Muestra los numeros exactos de experiencia en el HUD.
- Activa logs de experiencia, vida, muerte y opciones de nivel.

En Windows PowerShell, para probar desde consola:

```powershell
$env:SIGLO21_DEBUG="1"
godot
```

Si abrís desde Steam, conviene crear la variable de entorno de usuario en Windows y reiniciar Steam para que Godot la herede.

Tambien se puede activar desde un archivo `.env` en la raiz del proyecto. Formatos aceptados:

```text
SIGLO21_DEBUG=1
```

o estilo PowerShell:

```powershell
$env:SIGLO21_DEBUG="1"
```

Si existe `.env`, `Global.gd` lo lee al iniciar y usa ese valor antes de consultar `OS.get_environment()`.

## Spawner

Archivo: `Assets/Scripts/spawn.gd`

El spawner instancia enemigos cada vez que recibe timeout del timer del nivel.

Usa estos nodos hijos:

- `x1` y `x2`: rango horizontal.
- `y1` y `y2`: rango vertical.

Genera una posicion aleatoria:

```gdscript
Vector2(
	randf_range($x1.global_position.x, $x2.global_position.x),
	randf_range($y1.global_position.y, $y2.global_position.y)
)
```

Luego agrega el enemigo como hijo del spawner y le asigna posicion global.

El spawner ahora escala con `Global.survived_time`: reduce el tiempo entre oleadas, aumenta cantidad de enemigos, escala vida/daño/experiencia y puede generar enemigos fuera de camara con `spawn_outside_camera`.

Cada 5 minutos intenta spawnear un jefe desde `Scenes/BossRobot.tscn`. Mientras el jefe esta vivo, el spawner no crea enemigos normales. Cuando el jefe muere, se reanuda el spawn normal hasta el proximo bloque de 5 minutos.

Tambien maneja spawns especiales por tiempo:

- Drones cada `drone_wave_interval_seconds`.
- Minijefe esfera desde `sphere_miniboss_first_spawn_seconds` y luego cada `sphere_miniboss_interval_seconds`.

Para modificar spawn:

- Cambiar `base_wait_time`, `min_wait_time` y `wait_time_decrease_per_minute` en `spawn.gd`.
- Cambiar `extra_enemy_per_minute` para controlar cantidad por oleada.
- Cambiar `enemy_health_growth_per_minute` y `enemy_damage_growth_per_minute` para controlar escalado.
- Cambiar `boss_spawn_interval_seconds` para controlar cada cuanto aparece el boss.
- Cambiar `drone_wave_interval_seconds` y `drone_wave_count` para controlar la bandada de drones.
- Cambiar `sphere_miniboss_first_spawn_seconds` y `sphere_miniboss_interval_seconds` para controlar el minijefe esfera.
- Cambiar las posiciones de los markers.
- Cambiar `enemigo` por otra escena.
- Activar o desactivar `spawn_outside_camera`.

## Global singleton

Archivo: `Assets/Scripts/Global.gd`

`Global` esta registrado como autoload en `project.godot`.

Actualmente guarda:

```gdscript
var Player: Player = null
```

El player se registra en `_ready()`:

```gdscript
Global.Player = self
```

Los enemigos usan `Global.Player` para perseguir y atacar al jugador.

Mejora recomendada: si el juego crece, evitar depender demasiado de `Global` y usar grupos o señales para desacoplar sistemas.

## Pantalla inicial

Archivo: `Scenes/Menu.tscn`

El proyecto arranca en el menu inicial. `Iniciar partida` carga `Scenes/CharacterSelectMenu.tscn`; `Salir` cierra el juego. El script asociado es `Assets/Scripts/main_menu.gd`.

## Seleccion de personaje

Archivos:

- `Scenes/CharacterSelectMenu.tscn`
- `Assets/Scripts/character_select_menu.gd`
- `personajes.png`

Esta pantalla aparece entre el menu inicial y `Scenes/Nivel1/level_1.tscn`. Usa `personajes.png` como atlas y recorta los tres personajes con `AtlasTexture`.

Al elegir un personaje:

1. Guarda el indice en `Global.selected_character_id`.
2. Guarda el nombre en `Global.selected_character_name`.
3. Carga `Scenes/Nivel1/level_1.tscn`.

La seleccion cambia el sprite visible del `Player`. `Player.gd` lee `Global.selected_character_id`, recorta `personajes.png` con `AtlasTexture` y reemplaza la textura del nodo `OneHanded`.

Tambien queda preparada para futuras diferencias de stats o armas.

## Escena principal Level 1

Archivo: `Scenes/Nivel1/level_1.tscn`

Contiene:

- Un enemigo inicial.
- El spawner.
- Markers de rango de spawn.
- Un timer de spawn.
- El player.

El timer del nivel llama:

```gdscript
spawn._on_timer_timeout()
```

El `Player` de esta escena sobreescribe sus stats con un subresource local:

```text
base_max_health = 10.0
```

Esto significa que aunque `Player_stats.tres` tenga `base_max_health = 5.0`, en `level_1.tscn` el player puede arrancar con otro valor. Si queres usar siempre el recurso externo, elimina la sobreescritura local del `stats` en el inspector.

## Capas y grupos

Grupos definidos en `project.godot`:

- `Player`
- `Enemy`

Capas importantes observadas:

- Player: `collision_layer = 4`.
- Enemy: `collision_layer = 2`.
- Gema: `collision_mask = 4`, detecta al player.
- Bala: `Area2D collision_mask = 2`, detecta enemigos.
- Area de deteccion del player: `collision_mask = 2`, detecta enemigos.

Si algo no detecta colisiones, revisar:

1. Que el nodo tenga `CollisionShape2D`.
2. Que la shape no este deshabilitada.
3. Que el layer del objetivo coincida con el mask del detector.
4. Que el cuerpo este en el grupo esperado.

## Como modificar cosas comunes

### Cambiar vida inicial del jugador

Opcion 1: editar `Assets/Resources/Player_stats.tres`.

Opcion 2: editar el subresource local del player en `Scenes/Nivel1/level_1.tscn`.

Importante: si el nivel sobreescribe el recurso, ese valor gana sobre el `.tres`.

### Cambiar daño del jugador

Editar `base_attack` en el recurso `Stats` usado por el player.

El ataque natural tiene cap de `200` en `Stats.gd`. Las mejoras de arma multiplican despues de ese valor. Si se agrega una mejora global `ATTACK`, esa mejora permite superar el cap.

El daño aplicado por cada arma sale de:

```gdscript
shotgun = stats.current_attack * damage_multiplier
laser = stats.current_attack * base_damage_multiplier * damage_multiplier
axe = stats.current_attack * base_damage_multiplier * damage_multiplier
```

### Cambiar velocidad del jugador

Editar `base_move_speed` en el recurso `Stats` usado por el player. La variable `speed` queda como fallback si no hay recurso `Stats`.

### Cambiar daño del enemigo

Editar `damage` en `Scenes/enemigo1.tscn`.

### Cambiar vida del enemigo

Editar `max_health` en `Scenes/enemigo1.tscn`.

### Cambiar experiencia que da un enemigo

Editar `experience_value` en `Scenes/enemigo1.tscn`.

### Cambiar frecuencia de disparo

Editar el arma concreta:

- Shotgun: `cooldown_seconds` en `shotgun_weapon.gd`.
- Laser: `cooldown_seconds` en `laser_weapon.gd`.
- Hacha: `cooldown_seconds` en `axe_weapon.gd`.

Si un arma tiene `use_player_fire_rate = true`, usa:

```gdscript
1.0 / (stats.current_fire_rate * fire_rate_multiplier)
```

### Cambiar rango de disparo

Editar `base_weapon_range` en `Stats` para cambiar el rango global. `Player.gd` copia ese valor al `CollisionShape2D` de deteccion. Tambien se puede tocar `range_multiplier` en cada arma para ajustar un arma especifica.

### Cambiar velocidad de bala

Editar `speedBullet` en `Scenes/bullet_example.tscn` o en `bullet_example.gd`.

### Cambiar mejoras de nivel

Editar estas funciones en `Assets/Scripts/player.gd`:

- `_build_character_upgrade_pool()`: mejoras de personaje.
- `_build_weapon_unlock_pool()`: armas que pueden aparecer.
- `_get_next_weapon_upgrade()`: mejoras secuenciales de cada arma.

Ejemplo para agregar mas ataque:

```gdscript
StatBuff.new(Stats.BuffableStats.ATTACK, 0.25, StatBuff.BuffType.MULTIPLY)
```

### Cambiar el menu de mejoras

Editar `Scenes/UpgradeMenu.tscn` para layout, colores, texto y botones.

Editar `Assets/Scripts/upgrade_menu.gd` para comportamiento.

## Ideas de mejora

### 1. Profundizar daño y defensa

El daño y la defensa ya estan centralizados en `Stats.take_damage()`. Proximas mejoras posibles:

- Defensa porcentual en vez de defensa plana.
- Tipos de daño, por ejemplo fisico, electrico o fuego.
- Invulnerabilidad breve despues de recibir daño.
- Señales de feedback para sonido, camara o animaciones.

### 2. Expandir clases de enemigos

`Enemy.gd` ya existe como clase base y `BabyAllien` hereda de ella. Proximas mejoras posibles:

- Enemigos con stats propios usando `Stats`.
- Enemigos que no dropeen gemas siempre.
- Minijefes con ataques especiales.
- Jefes con fases.

### 3. Mejorar el sistema de mejoras

Ahora el pool de mejoras puede crecer, pero cada partida limita al jugador a 4 tipos distintos y cada uno puede elegirse como maximo 3 veces.

Se puede mejorar con:

- Pool de mejoras posibles.
- Eleccion aleatoria sin repetir.
- Rarezas.
- Mejoras desbloqueables.
- Mejoras de arma.
- Mejoras de velocidad, cooldown, cantidad de proyectiles, rango, magnetismo de gemas.

### 3.1. Sistema de armas actual

El GDD menciona armas steampunk como llave boomerang, rayos y variantes para ingeniero, mecanico o electricista. El proyecto ya separa las armas en clases propias para que el `Player` no concentre toda la logica.

Estructura recomendada:

- `Weapon.gd`: clase base con cooldown, daño, rango y metodo `try_attack()`.
- `ProjectileWeapon.gd`: arma que instancia proyectiles.
- `ShotgunWeapon.gd`: escopeta inicial del ingeniero.
- `LaserWeapon.gd`: arma que dispara una recta, opcionalmente con piercing.
- `AxeWeapon.gd`: hacha orbital inicial del mecanico.
- `BoomerangWeapon.gd`: arma que lanza una llave que vuelve.

El `Player` deberia tener una lista de armas y llamar algo como:

```gdscript
for weapon in weapons:
	weapon.try_attack(stats)
```

De esta forma las mejoras futuras pueden afectar:

- Daño global.
- Velocidad de disparo global.
- Cantidad de proyectiles.
- Duracion de lasers.
- Tamaño de area.
- Armas nuevas desbloqueables.

### 4. Agregar UI permanente

Se puede crear una HUD con:

- Barra de vida.
- Barra de experiencia.
- Nivel actual.
- Tiempo sobrevivido.
- Contador de enemigos derrotados.

`Stats` ya emite `health_changed` y `leveled_up`, asi que es facil conectarla.

### 5. Recoleccion magnetica de gemas

Ahora la gema solo se recolecta si el player pasa encima.

Una mejora interesante seria que al estar cerca, la gema viaje hacia el jugador. Para eso:

- Agregar un area de atraccion.
- En `gema.gd`, si detecta al player, moverse hacia el.
- Mantener la recoleccion al entrar en contacto.

### 6. Balancear el spawn

El spawner actualmente usa un timer fijo.

Se puede escalar dificultad con:

- Menor `wait_time` con el tiempo.
- Mas enemigos por oleada.
- Enemigos mas fuertes por minuto.
- Spawn fuera de camara.

### 7. Reemplazar prints por UI/debug controlado

Hay prints utiles para desarrollo:

- XP del player.
- Vida del player.
- Mejoras disponibles.

Cuando el juego este mas avanzado, conviene:

- Mover info a HUD.
- O usar una variable `debug_enabled`.

## Problemas comunes y solucion

### La gema no se recolecta

Revisar:

- `Gema` debe ser `Area2D`.
- Debe tener `CollisionShape2D`.
- Su `collision_mask` debe detectar el layer del player.
- El player debe tener metodo `add_experience()`.

### El enemigo no recibe daño

Revisar:

- El enemigo debe estar en grupo `"Enemy"`.
- La bala debe detectar el layer del enemigo.
- El enemigo debe tener metodo `TakeDamage()`.

### La bala se curva

La bala debe agregarse al nivel, no como hija del player.

En `Player.Shot()` se usa:

```gdscript
parent.add_child(b)
```

Si se usa `add_child(b)` dentro del player, la bala hereda el movimiento del jugador.

### El menu no responde cuando el juego esta pausado

Revisar:

- `UpgradeMenu` debe tener `process_mode = Node.PROCESS_MODE_ALWAYS`.
- Los botones tambien se configuran con `PROCESS_MODE_ALWAYS`.
- El menu debe estar agregado al arbol antes de pausar o debe procesar siempre.

### El player tiene mas vida de la esperada

Revisar si `level_1.tscn` esta sobreescribiendo el recurso `Stats` del player.

Tambien revisar las curvas de vida y que `_get_curve_multiplier()` siga normalizando nivel 1.

## Convenciones actuales

- Metodos de daño usan `TakeDamage` con mayuscula inicial.
- Grupos: `"Player"` y `"Enemy"`.
- El player se obtiene globalmente con `Global.Player`.
- El daño del player sale de `stats.current_attack`.
- La experiencia llega al player mediante `add_experience()`.
- Las mejoras se representan con `StatBuff`.

## Proximo paso recomendado

El siguiente paso mas natural seria probar balance en una partida completa: ritmo de spawn, daño recibido con defensa porcentual, fuerza de las rarezas y cuanto acelera el progreso la recoleccion magnetica.

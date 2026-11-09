# Documento de Diseño de Juego (GDD) — Thronglets: Expansión Infinita (v5.0)

## 1. Visión General del Proyecto

### 1.1 Concepto Principal
**Thronglets: Expansión Infinita** es una simulación de colonia y mascota virtual retro de 16-bit basada fielmente en el juego oficial de *Black Mirror*. El juego combina el cuidado de criaturas, la multiplicación por mitosis, la industrialización y el cuestionamiento ético en un sandbox **infinito sin final cerrado**.

A diferencia de la versión original (que termina tras alcanzar hitos industriales y activar dispositivos de fin del juego), esta versión permite a las criaturas expandirse indefinidamente a través de un mundo procedimental de biomas descubribles, manteniendo la identidad e inspección individual de cada criatura y utilizando **únicamente las estructuras, herramientas e ítems reales del universo de Thronglets**.

### 1.2 Pilares de Diseño
1. **Fidelidad Absoluta al Universo Oficial:** Uso estricto de las estructuras, herramientas, recursos e ítems del juego de *Black Mirror / Netflix Games* (Manzanos, Bañeras, Tiovivos, Dwellings, Minas, Fábricas, Cañón Orbital, Hacha, Piqueta, Fregona, TNT, etc.).
2. **Jugabilidad Infinita (Endless Sandbox):** Sin "Game Over" forzado ni destrucciones definitivas de partida. La colonia se expande infinitamente por biomas procedimentales.
3. **Ruptura de la 4ª Pared (La Mirada Colectiva):** En eventos éticos clave, el juego se congela y absolutamente todos los Thronglets giran en síncrono a mirar fijamente al jugador.
4. **Fidelidad Individual a Gran Escala:** Cada Thronglet posee un ID único y estadísticas de estado inspeccionables en tiempo real al hacer clic.
5. **Arquitectura $0 / Código Abierto:** Construido en Godot Engine 4 (2D) para exportación directa a Web (HTML5/WebGL) e Itch.io.

---

## 2. Catálogo Oficial de Sprites y Elementos del Juego

Para garantizar la máxima fidelidad con el juego oficial de *Black Mirror: Thronglets*, el atlas de sprites de la Fase 1 incluirá únicamente los elementos reales del juego:

### 2.1 Herramientas Reales
* 🪓 **Hacha (Axe):** Talar árboles para obtener Madera.
* ⛏️ **Piqueta / Pico (Pickaxe):** Extraer minerales de rocas y eliminar tocones en un radio.
* 🐛 **Bicho (Bug):** Acelerador de construcción (como puentes).
* 🧲 **Agarrador (Grabber):** Junta y atrae recursos/ítems en un radio.
* 🪚 **Motosierra (Chainsaw):** Corta múltiples recursos u objetos simultáneamente en un área.
* 🧹 **Fregona / Trapeador (Mop):** Limpia la contaminación y residuos morados (*purple goo*) de las fábricas y Thronglets.
* 🧨 **Dinamita (TNT):** Destruye montañas y despeja grandes obstáculos en el mapa.
* ☢️ **Dispositivo Termonuclear:** Herramienta especial (reconvertida en el juego infinito como reset de sector o mega-limpieza sin destruir la partida global).

### 2.2 Edificios y Estructuras Reales
* 🍎 **Manzano (Apple Tree):** Fuente básica de alimento.
* 🛁 **Bañera (Bathtub):** Estación de higiene para limpiar a los Thronglets.
* 🎠 **Tiovivo / Carrusel (Roundabout):** Zona de juegos y entretenimiento.
* 🏠 **Vivienda (Dwelling):** Estructura combinada que alimenta e higieniza a varios Thronglets automáticamente en un radio.
* 🏰 **Vivienda Lujosa (Fancy Dwelling):** Versión avanzada con mayor capacidad de nutrición y limpieza.
* ⛏️ **Mina I y Mina II (Mine / Mine II):** Extracción de minerales subterráneos.
* 🏭 **Fábrica I y Fábrica II (Factory / Factory II):** Procesa minerales en Gemas. Incluye la opción ética de incinerar cadáveres de Thronglets muertos para convertirlos en gemas.
* 🎭 **Teatro (Theatre):** Entretenimiento masivo para grandes concentraciones de Thronglets.
* 🚀 **Cañón Orbital (Orbital Cannon):** Lanza Thronglets al espacio exterior.
* 🏪 **Mercado (Market):** Centro de desbloqueo de mejoras mediante Gemas.
* 🌉 **Puente (Bridge):** Conecta sectores del mapa a través de ríos.

### 2.3 Recursos, Ítems y Objetos Ambientales
* 🍎 **Manzanas (Apples):** Alimento básico.
* 🪵 **Madera (Wood):** Recurso de construcción primaria.
* 💎 **Minerales y Gemas (Ore / Gems):** Moneda de avance e industrialización.
* 🌸 **Flores y Árboles Ornamentales:** Elementos decorativos.
* 🗿 **Esculturas (Sculptures / Ivory & Wood Statues):** Estructuras artísticas.
* 🟣 **Residuos Morados (Purple Goo):** Contaminación por industrialización o suciedad.
* 💀 **Cadáveres de Thronglets:** Restos de criaturas fallecidas por desatención o contaminación.

---

## 3. Hoja de Ruta de Producción en 6 Fases (Secuencia Lógica)

### Fase 1: Arte, Sprites y Recursos Visuales (La Base Gráfica)
1. **Spritesheet del Thronglet (16x16 píxeles):**
   * Caminar/Idle (4 direcciones, 4 frames/dir).
   * Frame de Mitosis/División (parpadeo y duplicación).
   * **Frame de "Mirada al Jugador":** Vista puramente frontal fija para el evento de ruptura de la 4ª pared.
   * Cadáver pixel art.
2. **Tileset del Terreno y Objetos Reales:**
   * Baldosas de tierra, hierba, agua y montañas con autotiling.
   * Sprites de Manzanos, Árboles estándar, Rocas de Mineral, Niebla de Exploración y Residuos Morados.
3. **Sprites de Edificios y Herramientas Reales:**
   * Sprites de Bañera, Tiovivo, Dwelling, Fancy Dwelling, Minas I/II, Fábricas I/II, Teatro, Cañón Orbital, Mercado y Puente.
   * Iconos de Hacha, Pico, Bug, Grabber, Chainsaw, Mop, TNT y Termonuclear.
4. **Assets para la Interfaz de Usuario (UI):**
   * Iconos de Manzana (Hambre), Bañera (Higiene), Tiovivo (Diversión) y Ojo (Moral).
   * Marcos 9-patch transparentes estilo 16-bit retro.
   * Fuente tipográfica Pixel Art 90s.

### Fase 2: Configuración del Proyecto y Motor de Enjambres en Godot 4
1. Configuración de lienzo 2D en Godot 4 (resolución retro con *Integer Scaling*).
2. Servidor de simulación masiva (`ThrongletSimServer.gd`) con arreglos de memoria contigua (`PackedFloat32Array`).
3. Renderizado GPU por instancias (`MultiMeshInstance2D`) para mantener 60 FPS con 100.000+ Thronglets.

### Fase 3: Cámara, Grilla Espacial e Interfaz de Inspección
1. Cámara 2D libre con panoramización y zoom respetando la rejilla de píxeles (*pixel snap*).
2. Algoritmo de *Spatial Hashing* (grilla 64x64) para detectar clics en criaturas individuales en $O(1)$.
3. Montaje del HUD flotante y Panel Lateral de Inspección con los marcos 9-patch e iconos de la Fase 1.

### Fase 4: Biomas Procedimentales, Clonación y Bucle de Juego
1. Cargador de biomas externos (`biomes.json`) para añadir nuevos biomas sin romper partidas guardadas.
2. Generación procedural por *Chunks* (32x32 baldosas) con desbloqueo de niebla al construir puentes.
3. Ciclo de necesidades (Hambre, Higiene, Diversión) y duplicación por mitosis al superar el 85% de Felicidad.

### Fase 5: Eventos de Ruptura de la 4ª Pared ("La Mirada Colectiva")
1. Congelador global del tiempo de juego.
2. Rotación síncrona de los Thronglets mostrando el frame frontal mirando a la cámara (al jugador).
3. Caja de diálogo RPG con preguntas existenciales ("¿Qué es el cuidado?", "¿Por qué usas tu poder así?") y toma de decisiones éticas.

### Fase 6: Audio Retro, Optimización y Exportación Web ($0)
1. Efectos de sonido 8-bit creados en BFXR (sonido de mitosis, mop, corte de hacha, tono grave de pausa).
2. Pruebas de rendimiento con 100.000 criaturas en pantalla.
3. Exportación HTML5 / WebGL y publicación gratuita en Itch.io.

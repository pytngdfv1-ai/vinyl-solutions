// Generado desde docs/MANUAL.md: contenido del manual de la pantalla "Acerca de".
// Marcas: **negrita**, ~~cursiva~~, [[botón]].

class ManualBlock {
  const ManualBlock(this.kind, {this.text = '', this.title = '', this.items = const [], this.rows = const []});

  /// p | h | ul | ol | tip | table
  final String kind;
  final String text;
  final String title;
  final List<String> items;
  final List<List<String>> rows;
}

class ManualSection {
  const ManualSection(this.id, this.title, this.subtitle, this.icon, this.blocks);
  final String id;
  final String title;
  final String subtitle;

  /// Nombre del icono (ver about_screen.dart).
  final String icon;
  final List<ManualBlock> blocks;
}

const manualSections = <ManualSection>[
  ManualSection("inicio", "Primeros pasos", "Agrega tu música en tres minutos", "arrow_forward", [
    ManualBlock("p", text: "Mi Biblioteca lee tus archivos de audio y arma la colección sola. Puedes usar una nube, una carpeta del teléfono o las dos."),
    ManualBlock("ol", items: ["Toca [[+]] arriba a la derecha.", "Elige **Conectar nube** e ingresa tu correo de Koofr y una contraseña de aplicación. O elige **Carpeta del teléfono**.", "Indica la carpeta de música y espera el escaneo. La barra fina de arriba muestra el avance.", "Los discos aparecen ordenados en cajones. Toca uno y escucha."]),
    ManualBlock('tip', title: "Contraseña de aplicación.", text: "Créala en los ajustes de Koofr. Mi Biblioteca la guarda cifrada en tu dispositivo y nunca la envía a terceros."),
    ManualBlock("h", text: "Varias cuentas"),
    ManualBlock("p", text: "Puedes conectar más de una cuenta. Cada una se muestra como una biblioteca con el nombre que le pongas. La palabra \"Koofr\" no aparece: se muestra como **Nube**."),
  ]),
  ManualSection("biblioteca", "La biblioteca y los cajones", "Álbumes, sueltos, covers y sin clasificar", "view_agenda_outlined", [
    ManualBlock("p", text: "La app clasifica sola cada disco por tipo y por idioma, y los guarda en cajones."),
    ManualBlock('table', rows: [["Cajón", "Qué contiene"], ["**Álbumes**", "Discos completos. Se ven como discos grandes en el tocadiscos."], ["**Sueltos**", "Temas sin álbum completo, o carpetas con pocos temas. Suenan en el cassette."], ["**Covers**", "Versiones de otros artistas. Se guardan como cassettes en una estantería de lomos finos."], ["**Sin clasificar**", "Lo que la app no pudo ubicar. Puedes corregirlo en la ficha."]]),
    ManualBlock("h", text: "Cómo decide el idioma"),
    ManualBlock("p", text: "Primero mira la etiqueta del archivo, luego la carpeta de categoría, después MusicBrainz y por último el texto de los títulos. Si lo cambias a mano, la app nunca lo vuelve a tocar."),
    ManualBlock("h", text: "Renombrar un cajón"),
    ManualBlock("p", text: "Mantén presionado el cajón en el menú principal y escribe el nombre que quieras."),
  ]),
  ManualSection("escuchar", "Escuchar", "Tocadiscos, cassette, portada y letras", "album", [
    ManualBlock("p", text: "Al abrir un disco ves el reproductor arriba y la portada abajo. Toca el plato o el botón de play para empezar."),
    ManualBlock("ul", items: ["**Álbumes:** tocadiscos con el brazo que baja al borde del disco. Al cambiar de tema el brazo se levanta y vuelve a bajar.", "**Sueltos y covers:** cassette con los dos carretes que giran y la cinta que pasa de un rollo al otro.", "**Portada:** tócala para darla vuelta. En el reverso están la lista de temas y los datos del disco.", "**Libreto:** en la portada, desliza hacia el costado para ver las páginas del libreto.", "**Letra:** el icono de la letra abre la hoja con la canción que suena."]),
    ManualBlock('tip', title: "Sigue sonando.", text: "La música continúa si cierras el disco. Abajo aparece una cápsula con el tema actual; tócala para volver."),
  ]),
  ManualSection("disco", "Ficha del disco", "Idioma, cover, mover y subir a la nube", "info_outline", [
    ManualBlock("p", text: "Toca el icono [[i]] en la pantalla del disco para abrir su ficha."),
    ManualBlock("ul", items: ["**Es un cover:** lo pasa a la estantería de cassettes. Si no tiene portada, la app busca la del tema.", "**Idioma:** elige Inglés o Español. La app te ofrece mover también la carpeta a la categoría correcta.", "**Mover a…:** mueve la carpeta completa del disco en la nube, con portada y libreto, y conserva todos tus datos.", "**Subir a la nube…:** para discos del teléfono. Copia la carpeta a tu nube sin pisar archivos y conserva portada, idioma y marca de cover. La copia del teléfono solo se borra si lo pides, y únicamente cuando terminó la subida.", "**Buscar portada / PDF:** abre Cover Studio con el artista y el álbum ya escritos."]),
  ]),
  ManualSection("studio", "Cover Studio", "Busca y guarda portadas y PDF", "search", [
    ManualBlock("p", text: "Busca carátulas, contraportadas, discos y páginas de libreto en iTunes, Deezer, MusicBrainz y Cover Art Archive. Los PDF vienen de Internet Archive."),
    ManualBlock("ol", items: ["Escribe artista y álbum, y toca [[Buscar]].", "Abre un álbum. Filtra por tipo y toca las imágenes que quieras. Mantén presionada una para verla grande.", "La estrella la deja como portada. [[Guardar en la carpeta]] la copia junto a la música."]),
    ManualBlock("p", text: "Todo se guarda en la carpeta del disco, en la nube o en el teléfono, con nombres como \"Portada\" y \"Portada (2)\". Nunca pisa un archivo existente."),
    ManualBlock('tip', title: "Desde el menú.", text: "Cover Studio también está en el menú **+**. Si no abriste un disco, te pregunta en cuál guardar."),
  ]),
  ManualSection("libretos", "Libretos y PDF", "Léelos dentro de la app", "menu_book", [
    ManualBlock("p", text: "Si la carpeta del disco tiene imágenes o PDF, el icono de libreto aparece arriba en la pantalla del disco."),
    ManualBlock("ul", items: ["**Versión liviana:** la app convierte un PDF en imágenes ligeras para abrirlo rápido y las guarda junto al PDF original.", "**Imágenes a PDF:** reúne las páginas de un libreto en un solo PDF y lo guarda en la carpeta del disco."]),
    ManualBlock("p", text: "Los dos interruptores están en **Ajustes de biblioteca**: \"auto-liviano\" y \"al lado\"."),
  ]),
  ManualSection("playlists", "Playlists", "Tus listas, en orden o aleatorias", "playlist_add", [
    ManualBlock("ol", items: ["En la pantalla de un disco, toca el icono de lista con el signo más, junto a los controles.", "Elige una playlist o crea una nueva.", "Abre **Playlists** desde el menú [[+]]. Reordena arrastrando y quita deslizando.", "Toca [[Aleatorio]] o [[En orden]]. Los temas suenan encadenados, sin pausas."]),
    ManualBlock("p", text: "Mientras suena una playlist, la cápsula de abajo te lleva al modo DJ."),
  ]),
  ManualSection("dj", "Modo DJ y DJ en vivo", "Mesa de dos platos en pantalla horizontal", "graphic_eq", [
    ManualBlock("h", text: "Modo DJ"),
    ManualBlock("p", text: "Muestra tu playlist sobre una mesa con dos platos. El tema que suena gira en un plato con su portada de etiqueta y el siguiente espera en el otro. Abajo ves la portada actual y las que vienen después. Toca una para saltar."),
    ManualBlock("h", text: "DJ en vivo"),
    ManualBlock("p", text: "En una playlist, toca [[DJ en vivo]]. Suenan los dos platos a la vez y tú mezclas."),
    ManualBlock("ul", items: ["**Crossfader:** arrastra la perilla de la mesa para pasar de un plato al otro.", "**Pitch:** arrastra el carril rojo de cada plato (±8 %). Doble toque lo deja en cero.", "**Cue y play:** en la barra de cada plato. El botón start/stop de la mesa también funciona.", "**Auto-mix:** hace el fundido solo cerca del final de cada tema. Elige 4, 8, 12 o 16 segundos."]),
    ManualBlock("h", text: "AutoDJ"),
    ManualBlock("p", text: "Analiza el tempo de cada tema, elige entre los próximos el de tempo más cercano, iguala la velocidad del que entra y lo arranca sin silencio. El BPM aparece sobre cada plato."),
    ManualBlock('tip', title: "Primera vez.", text: "El análisis baja el inicio de cada tema de la nube. Tarda unos segundos y queda guardado para la próxima."),
  ]),
  ManualSection("nube", "Nube y duplicados", "Mantén tu colección ordenada", "cloud_outlined", [
    ManualBlock("p", text: "Desde el menú [[+]] abre **Duplicados**. La app agrupa álbumes y temas repetidos y los marca como **Exacto** o **Parecido**."),
    ManualBlock("ul", items: ["Sugiere conservar la copia con más datos: portada, PDF y libreto. Tú puedes elegir otra.", "**Quitar las otras** mueve las copias de la nube a una carpeta ~~_duplicados~~, o las borra si lo eliges.", "En un álbum se quita la carpeta entera. En un tema suelto, solo su archivo."]),
    ManualBlock('tip', title: "Cuidado.", text: "Borrar en la nube no se puede deshacer. Mover a _duplicados sí, y la app ignora esa carpeta al escanear."),
  ]),
  ManualSection("datos", "Copia de seguridad y ajustes", "Protege lo que hiciste a mano", "lock_outline", [
    ManualBlock("h", text: "Copia de seguridad"),
    ManualBlock("p", text: "Menú [[+]] → **Copia de seguridad**. Crea un archivo ~~.vinylbackup~~ cifrado con una clave que eliges. Guarda tus cuentas, ajustes, discos agregados a mano, clasificación, covers y playlists. La música y las portadas se reconstruyen al sincronizar."),
    ManualBlock("h", text: "Ajustes de biblioteca"),
    ManualBlock("ul", items: ["**Mínimo de temas por álbum:** por debajo de ese número, una carpeta se trata como temas sueltos.", "**Token de Discogs:** opcional, mejora la búsqueda de portadas. Se guarda cifrado.", "**Auto-liviano y al lado:** controlan cómo se crean los libretos livianos."]),
  ]),
  ManualSection("faq", "Preguntas frecuentes", "Lo que más se consulta", "help_outline", [
    ManualBlock("h", text: "No aparece mi música"),
    ManualBlock("p", text: "Revisa que la carpeta indicada tenga archivos de audio (FLAC, MP3, M4A, OGG, OPUS, WAV o AAC) y que la contraseña de aplicación sea correcta. Vuelve a escanear desde la cuenta."),
    ManualBlock("h", text: "Un disco quedó en el idioma equivocado"),
    ManualBlock("p", text: "Abre su ficha y elige el idioma. Se recuerda para ese artista."),
    ManualBlock("h", text: "Un álbum se ve como suelto"),
    ManualBlock("p", text: "Pasa cuando la carpeta tiene pocos temas. Cambia el mínimo en **Ajustes de biblioteca**."),
    ManualBlock("h", text: "No suena en la nube"),
    ManualBlock("p", text: "Comprueba tu conexión. La app avisa si Koofr no responde y reintenta al abrir el disco."),
    ManualBlock("h", text: "¿Mis datos están seguros?"),
    ManualBlock("p", text: "Todo vive en tu dispositivo. Solo se contacta a internet para buscar portadas, letras y libretos, y para hablar con tu nube."),
  ]),
];

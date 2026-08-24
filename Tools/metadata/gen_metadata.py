#!/usr/bin/env python3
"""Writes fastlane/metadata/<locale>/*.txt for all seven App Store locales.

Run:  python3 Tools/metadata/gen_metadata.py

Single source of truth for the 1.3.0 listing copy. Re-running it overwrites the
locale dirs, so edit here rather than in the .txt files.
"""
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[2] / "fastlane" / "metadata"

URLS = {
    "marketing_url": "https://falsepeak.ch",
    "support_url": "https://falsepeak.ch/contact",
    "privacy_url": "https://falsepeak.ch/privacy",
}

NAME = "Reverso by Cluso"

# App Store Connect field limits.
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100,
          "promotional_text": 170, "description": 4000, "release_notes": 4000}

# ---------------------------------------------------------------------------
# en-US
# ---------------------------------------------------------------------------
EN = dict(
    subtitle="Dub Movie Scenes in Your Voice",
    keywords=["choicer", "voicer", "dubbing", "voiceover", "impression", "mimic",
              "reverse", "backwards", "sing", "karaoke", "anime", "mic", "pack", "act"],
    promotional_text=(
        "New in 1.3.0: Movie Scene Dub, with two original scenes included. Record your voice line by line, then export the finished dub and share it. Now in seven languages."
    ),
    description="""Reverso is two voice games in one app — and neither of them needs anything but your microphone.

MOVIE SCENE DUB

Load a scene and dub it yourself. Reverso plays you the original line, shows you the picture and the words, and gives you the exact length to hit. Then you record your take. The waveform of the original sits under yours, so you can see where you came in early, where you rushed, and where you left a gap.

• Line by line, at your own pace — stop and pick it up again whenever you like
• The original delivery in your headphones while you record, if you want it
• Every character colour-coded, so you always know who is speaking
• A pacing bar that turns amber the moment you run past the original
• Watch the original, play your dub back, or export the whole scene as a video
• Overlapping dialogue is mixed on separate lanes, so two people talking over each other actually sound like it

When you are done, Reverso renders the scene with your voice in it and hands you a video to share.

TWO SCENES TO START WITH

Reverso comes with two original scenes, written and made for this app — characters, dialogue, voices and pictures, all ours. Open the mode and there is already something to dub.

After that, the shelf is yours to fill. Reverso does not include, host or provide any films. Community dub packs are made and shared by other players — you download the ones you want and import the folder or .zip from Files, AirDrop or any share sheet. You are responsible for holding the rights to whatever you dub.

REVERSE SINGING

The original game. Record a song and Reverso flips it. Sing the backwards version you hear, and the app flips your attempt back — if you got it right, you come out singing the real song. It scores how close you got.

• Two interfaces: big simple buttons, or the full waveform with loop, speed and pitch
• Save your best takes and come back to them

PRIVATE BY DESIGN

Everything happens on this device. Your recordings, your takes and your exported dubs never leave it — no account, no sign-up, no ads, nothing to upload. The app collects anonymous usage statistics to guide what gets built next, never the contents of a recording.

Free. No subscription, no in-app purchases, nothing to unlock.

Built in Switzerland. Made with care in Zürich.""",
    release_notes="""Movie Scene Dub — the second game.

• Two original scenes included, so there is something to dub the moment you open it
• Import more: a dub pack folder or .zip from Files, AirDrop or any share sheet
• Record your voice line by line over the scene, with the original waveform under yours and a pacing bar that tells you when you are running long
• Hear the original in your headphones while you record
• Watch the original, play your dub back, or export the finished scene as a video and share it
• Overlapping dialogue now mixes correctly — two characters talking over each other sum properly instead of one swallowing the other

Reverso now speaks French, Italian, Japanese and Portuguese.

New onboarding that shows you both games before it asks for the microphone.""",
)

# ---------------------------------------------------------------------------
# es-ES
# ---------------------------------------------------------------------------
ES = dict(
    subtitle="Dobla escenas con tu voz",
    keywords=["choicer", "voicer", "dubbing", "voiceover", "doblaje", "imitar",
              "imitacion", "reves", "invertido", "cantar", "karaoke", "anime", "micro"],
    promotional_text=(
        "Nuevo en 1.3.0: Doblaje de Escena, con dos escenas originales incluidas. Graba tu voz línea a línea y exporta el doblaje para compartirlo. Ya en siete idiomas."
    ),
    description="""Reverso son dos juegos de voz en una sola app — y ninguno necesita nada más que tu micrófono.

DOBLAJE DE ESCENA

Carga una escena y dóblala tú. Reverso te reproduce la línea original, te enseña la imagen y el texto, y te marca exactamente cuánto dura. Luego grabas tu toma. La onda de la original queda debajo de la tuya, así que ves dónde entraste antes de tiempo, dónde corriste y dónde dejaste un hueco.

• Línea a línea, a tu ritmo: párate y retómalo cuando quieras
• La interpretación original en tus auriculares mientras grabas, si te apetece
• Cada personaje con su color, para saber siempre quién habla
• Una barra de ritmo que se pone ámbar en cuanto te pasas de la original
• Mira la original, escucha tu doblaje o exporta la escena entera en vídeo
• Los diálogos superpuestos se mezclan en pistas separadas, así que dos personajes hablando a la vez suenan como tal

Al terminar, Reverso renderiza la escena con tu voz dentro y te da un vídeo para compartir.

DOS ESCENAS PARA EMPEZAR

Reverso trae dos escenas originales, escritas y hechas para esta app: personajes, diálogos, voces e imágenes, todo nuestro. Abres el modo y ya hay algo que doblar.

A partir de ahí, la estantería la llenas tú. Reverso no incluye, no aloja y no proporciona ninguna película. Los packs de doblaje los hacen y los comparten otros jugadores: descargas los que quieras e importas la carpeta o el .zip desde Archivos, AirDrop o cualquier hoja de compartir. Tú eres responsable de tener los derechos de lo que dobles.

CANTO INVERTIDO

El juego original. Graba una canción y Reverso la invierte. Canta la versión al revés que oyes y la app le da la vuelta a tu intento: si lo has clavado, acabas cantando la canción de verdad. Te puntúa lo cerca que has estado.

• Dos interfaces: botones grandes y sencillos, o la onda completa con bucle, velocidad y tono
• Guarda tus mejores tomas y vuelve a ellas

PRIVADA POR DISEÑO

Todo ocurre en este dispositivo. Tus grabaciones, tus tomas y tus doblajes exportados no salen de aquí: sin cuenta, sin registro, sin anuncios y sin nada que subir. La app recoge estadísticas de uso anónimas para saber qué construir después, nunca el contenido de una grabación.

Gratis. Sin suscripción, sin compras dentro de la app, sin nada que desbloquear.

Hecho en Suiza. Hecho con cuidado en Zúrich.""",
    release_notes="""Doblaje de Escena — el segundo juego.

• Dos escenas originales incluidas, para tener algo que doblar nada más abrirlo
• Importa más: una carpeta o un .zip de pack desde Archivos, AirDrop o cualquier hoja de compartir
• Graba tu voz línea a línea sobre la escena, con la onda original bajo la tuya y una barra de ritmo que te avisa cuando te alargas
• Escucha la original en tus auriculares mientras grabas
• Mira la original, escucha tu doblaje o exporta la escena terminada en vídeo y compártela
• Los diálogos superpuestos ahora se mezclan bien: dos personajes hablando a la vez suman correctamente en vez de taparse

Reverso ya habla francés, italiano, japonés y portugués.

Nueva introducción que te enseña los dos juegos antes de pedirte el micrófono.""",
)

# ---------------------------------------------------------------------------
# ca
# ---------------------------------------------------------------------------
CA = dict(
    subtitle="Dobla escenes amb la teva veu",
    keywords=["choicer", "voicer", "dubbing", "voiceover", "doblatge", "doblar",
              "imitar", "reves", "invertit", "cantar", "karaoke", "anime", "micro"],
    promotional_text=(
        "Nou a la 1.3.0: Doblatge d'Escena, amb dues escenes originals incloses. Grava la teva veu línia a línia i exporta el doblatge per compartir-lo. Ja en set idiomes."
    ),
    description="""Reverso són dos jocs de veu en una sola app — i cap dels dos necessita res més que el teu micròfon.

DOBLATGE D'ESCENA

Carrega una escena i dobla-la tu. Reverso et reprodueix la línia original, t'ensenya la imatge i el text, i et marca exactament quant dura. Després graves la teva presa. L'ona de l'original queda sota la teva, així que veus on has entrat abans d'hora, on has corregut i on has deixat un forat.

• Línia a línia, al teu ritme: atura't i reprèn-ho quan vulguis
• La interpretació original als auriculars mentre graves, si et ve de gust
• Cada personatge amb el seu color, per saber sempre qui parla
• Una barra de ritme que es torna ambre així que et passes de l'original
• Mira l'original, escolta el teu doblatge o exporta l'escena sencera en vídeo
• Els diàlegs superposats es mesclen en pistes separades, així que dos personatges parlant alhora sonen com tal

Quan acabes, Reverso renderitza l'escena amb la teva veu a dins i et dona un vídeo per compartir.

DUES ESCENES PER COMENÇAR

Reverso ve amb dues escenes originals, escrites i fetes per a aquesta app: personatges, diàlegs, veus i imatges, tot nostre. Obres el mode i ja hi ha alguna cosa per doblar.

A partir d'aquí, la prestatgeria l'omples tu. Reverso no inclou, no allotja i no proporciona cap pel·lícula. Els packs de doblatge els fan i els comparteixen altres jugadors: descarregues els que vulguis i importes la carpeta o el .zip des de Fitxers, AirDrop o qualsevol full de compartir. Tu ets responsable de tenir els drets d'allò que doblis.

CANT INVERTIT

El joc original. Grava una cançó i Reverso la inverteix. Canta la versió del revés que sents i l'app gira el teu intent: si l'has clavat, acabes cantant la cançó de debò. Et puntua com de a prop has estat.

• Dues interfícies: botons grans i senzills, o l'ona completa amb bucle, velocitat i to
• Desa les teves millors preses i torna-hi

PRIVADA PER DISSENY

Tot passa en aquest dispositiu. Les teves gravacions, les teves preses i els teus doblatges exportats no en surten: sense compte, sense registre, sense anuncis i sense res per pujar. L'app recull estadístiques d'ús anònimes per saber què construir després, mai el contingut d'una gravació.

Gratis. Sense subscripció, sense compres dins de l'app, sense res per desbloquejar.

Fet a Suïssa. Fet amb cura a Zuric.""",
    release_notes="""Doblatge d'Escena — el segon joc.

• Dues escenes originals incloses, per tenir alguna cosa per doblar de seguida
• Importa'n més: una carpeta o un .zip de pack des de Fitxers, AirDrop o qualsevol full de compartir
• Grava la teva veu línia a línia sobre l'escena, amb l'ona original sota la teva i una barra de ritme que t'avisa quan t'allargues
• Escolta l'original als auriculars mentre graves
• Mira l'original, escolta el teu doblatge o exporta l'escena acabada en vídeo i comparteix-la
• Els diàlegs superposats ara es mesclen bé: dos personatges parlant alhora sumen correctament en comptes de tapar-se

Reverso ja parla francès, italià, japonès i portuguès.

Nova introducció que t'ensenya els dos jocs abans de demanar-te el micròfon.""",
)

# ---------------------------------------------------------------------------
# fr-FR
# ---------------------------------------------------------------------------
FR = dict(
    subtitle="Double des scènes de film",
    keywords=["choicer", "voicer", "dubbing", "voiceover", "doublage", "doubler",
              "imitation", "envers", "chanter", "karaoke", "anime", "micro"],
    promotional_text=(
        "Nouveau en 1.3.0 : Doublage de Scène, avec deux scènes originales incluses. Enregistre ta voix réplique par réplique, exporte ton doublage et partage-le."
    ),
    description="""Reverso, ce sont deux jeux de voix dans une seule app — et aucun des deux n'a besoin d'autre chose que ton micro.

DOUBLAGE DE SCÈNE

Charge une scène et double-la toi-même. Reverso te joue la réplique originale, t'affiche l'image et le texte, et te donne la durée exacte à tenir. Ensuite tu enregistres ta prise. La forme d'onde de l'originale se place sous la tienne : tu vois où tu es entré trop tôt, où tu as accéléré et où tu as laissé un blanc.

• Réplique par réplique, à ton rythme — arrête-toi et reprends quand tu veux
• L'interprétation originale dans ton casque pendant que tu enregistres, si tu le souhaites
• Chaque personnage a sa couleur, pour toujours savoir qui parle
• Une barre de rythme qui passe à l'ambre dès que tu dépasses l'originale
• Regarde l'originale, écoute ton doublage ou exporte la scène entière en vidéo
• Les dialogues qui se chevauchent sont mixés sur des pistes séparées : deux personnages qui se coupent la parole sonnent enfin comme tels

À la fin, Reverso rend la scène avec ta voix dedans et te donne une vidéo à partager.

DEUX SCÈNES POUR COMMENCER

Reverso arrive avec deux scènes originales, écrites et fabriquées pour cette app : personnages, dialogues, voix et images, tout est de nous. Tu ouvres le mode et il y a déjà quelque chose à doubler.

Ensuite, l'étagère est à toi. Reverso n'inclut, n'héberge et ne fournit aucun film. Les packs de doublage sont créés et partagés par les autres joueurs : tu télécharges ceux que tu veux et tu importes le dossier ou le .zip depuis Fichiers, AirDrop ou n'importe quelle feuille de partage. Tu es responsable de détenir les droits sur ce que tu doubles.

CHANT INVERSÉ

Le jeu d'origine. Enregistre une chanson et Reverso l'inverse. Chante la version à l'envers que tu entends, et l'app retourne ton essai — si tu as visé juste, tu ressors en train de chanter la vraie chanson. Elle note à quel point tu t'en es approché.

• Deux interfaces : de gros boutons simples, ou la forme d'onde complète avec boucle, vitesse et hauteur
• Garde tes meilleures prises et reviens-y

PRIVÉ PAR CONCEPTION

Tout se passe sur cet appareil. Tes enregistrements, tes prises et tes doublages exportés n'en sortent jamais : pas de compte, pas d'inscription, pas de pub, rien à envoyer. L'app collecte des statistiques d'usage anonymes pour savoir quoi construire ensuite, jamais le contenu d'un enregistrement.

Gratuit. Pas d'abonnement, pas d'achat intégré, rien à débloquer.

Conçu en Suisse. Fait avec soin à Zurich.""",
    release_notes="""Doublage de Scène — le deuxième jeu.

• Deux scènes originales incluses, pour avoir quelque chose à doubler tout de suite
• Importe-en d'autres : un dossier ou un .zip de pack depuis Fichiers, AirDrop ou n'importe quelle feuille de partage
• Enregistre ta voix réplique par réplique sur la scène, avec la forme d'onde originale sous la tienne et une barre de rythme qui te prévient quand tu dépasses
• Écoute l'originale dans ton casque pendant que tu enregistres
• Regarde l'originale, réécoute ton doublage ou exporte la scène terminée en vidéo et partage-la
• Les dialogues qui se chevauchent sont enfin mixés correctement : deux personnages qui parlent en même temps s'additionnent au lieu de s'annuler

Reverso parle maintenant français, italien, japonais et portugais.

Nouvelle introduction qui te montre les deux jeux avant de demander le micro.""",
)

# ---------------------------------------------------------------------------
# it
# ---------------------------------------------------------------------------
IT = dict(
    subtitle="Doppia scene con la tua voce",
    keywords=["choicer", "voicer", "dubbing", "voiceover", "doppiaggio",
              "imitazione", "contrario", "invertito", "cantare", "karaoke", "anime"],
    promotional_text=(
        "Novità nella 1.3.0: Doppiaggio di Scena, con due scene originali incluse. Registra la tua voce battuta per battuta, poi esporta il doppiaggio e condividilo."
    ),
    description="""Reverso sono due giochi di voce in una sola app — e nessuno dei due ha bisogno di altro che del tuo microfono.

DOPPIAGGIO DI SCENA

Carica una scena e doppiala tu. Reverso ti riproduce la battuta originale, ti mostra l'immagine e il testo, e ti dà la durata esatta da rispettare. Poi registri la tua take. La forma d'onda dell'originale sta sotto la tua, così vedi dove sei entrato in anticipo, dove hai corso e dove hai lasciato un vuoto.

• Battuta per battuta, al tuo ritmo: fermati e riprendi quando vuoi
• L'interpretazione originale in cuffia mentre registri, se ti va
• Ogni personaggio ha il suo colore, così sai sempre chi parla
• Una barra di ritmo che diventa ambra appena superi l'originale
• Guarda l'originale, riascolta il tuo doppiaggio o esporta l'intera scena in video
• I dialoghi sovrapposti vengono mixati su piste separate, così due personaggi che parlano insieme suonano davvero così

Alla fine Reverso renderizza la scena con la tua voce dentro e ti consegna un video da condividere.

DUE SCENE PER INIZIARE

Reverso arriva con due scene originali, scritte e realizzate per questa app: personaggi, dialoghi, voci e immagini, tutto nostro. Apri la modalità e c'è già qualcosa da doppiare.

Da lì in poi lo scaffale lo riempi tu. Reverso non include, non ospita e non fornisce alcun film. I pack di doppiaggio sono creati e condivisi dagli altri giocatori: scarichi quelli che vuoi e importi la cartella o lo .zip da File, AirDrop o qualsiasi foglio di condivisione. Sei tu il responsabile dei diritti su ciò che doppi.

CANTO INVERTITO

Il gioco originale. Registra una canzone e Reverso la inverte. Canta la versione al contrario che senti e l'app ribalta il tuo tentativo: se l'hai presa, esci cantando la canzone vera. Ti dà un punteggio su quanto ci sei andato vicino.

• Due interfacce: pulsanti grandi e semplici, oppure la forma d'onda completa con loop, velocità e tonalità
• Salva le tue take migliori e torna ad ascoltarle

PRIVATO PER SCELTA

Tutto avviene su questo dispositivo. Le tue registrazioni, le tue take e i tuoi doppiaggi esportati non escono mai da qui: nessun account, nessuna registrazione, nessuna pubblicità, niente da caricare. L'app raccoglie statistiche d'uso anonime per capire cosa costruire dopo, mai il contenuto di una registrazione.

Gratis. Nessun abbonamento, nessun acquisto in-app, niente da sbloccare.

Creato in Svizzera. Fatto con cura a Zurigo.""",
    release_notes="""Doppiaggio di Scena — il secondo gioco.

• Due scene originali incluse, così c'è subito qualcosa da doppiare
• Importane altre: una cartella o uno .zip di pack da File, AirDrop o qualsiasi foglio di condivisione
• Registra la tua voce battuta per battuta sulla scena, con la forma d'onda originale sotto la tua e una barra di ritmo che ti avverte quando ti stai allungando
• Ascolta l'originale in cuffia mentre registri
• Guarda l'originale, riascolta il tuo doppiaggio o esporta la scena finita in video e condividila
• I dialoghi sovrapposti ora si mixano correttamente: due personaggi che parlano insieme si sommano invece di coprirsi

Reverso ora parla francese, italiano, giapponese e portoghese.

Nuova introduzione che ti mostra entrambi i giochi prima di chiederti il microfono.""",
)

# ---------------------------------------------------------------------------
# pt-PT
# ---------------------------------------------------------------------------
PT = dict(
    subtitle="Dobra cenas com a tua voz",
    keywords=["choicer", "voicer", "dubbing", "voiceover", "dobragem", "dublagem",
              "imitar", "imitacao", "contrario", "cantar", "karaoke", "anime"],
    promotional_text=(
        "Novo na 1.3.0: Dobragem de Cena, com duas cenas originais incluídas. Grava a tua voz falha a falha e exporta a dobragem para partilhar. Já em sete idiomas."
    ),
    description="""O Reverso são dois jogos de voz numa só app — e nenhum deles precisa de mais nada além do teu microfone.

DOBRAGEM DE CENA

Carrega uma cena e dobra-a tu. O Reverso reproduz-te a fala original, mostra-te a imagem e o texto, e dá-te a duração exacta a cumprir. Depois gravas a tua take. A onda da original fica por baixo da tua, por isso vês onde entraste cedo demais, onde aceleraste e onde deixaste um vazio.

• Fala a fala, ao teu ritmo: pára e retoma quando quiseres
• A interpretação original nos teus auscultadores enquanto gravas, se quiseres
• Cada personagem com a sua cor, para saberes sempre quem está a falar
• Uma barra de ritmo que fica âmbar assim que passas da original
• Vê a original, ouve a tua dobragem ou exporta a cena inteira em vídeo
• Os diálogos sobrepostos são misturados em pistas separadas, por isso duas personagens a falar ao mesmo tempo soam mesmo assim

No fim, o Reverso renderiza a cena com a tua voz lá dentro e entrega-te um vídeo para partilhar.

DUAS CENAS PARA COMEÇAR

O Reverso vem com duas cenas originais, escritas e feitas para esta app: personagens, diálogos, vozes e imagens, tudo nosso. Abres o modo e já há alguma coisa para dobrar.

A partir daí, a prateleira é tua. O Reverso não inclui, não aloja e não fornece qualquer filme. Os packs de dobragem são feitos e partilhados pelos outros jogadores: descarregas os que quiseres e importas a pasta ou o .zip a partir de Ficheiros, AirDrop ou qualquer folha de partilha. És tu o responsável por deteres os direitos daquilo que dobras.

CANTO INVERTIDO

O jogo original. Grava uma música e o Reverso inverte-a. Canta a versão ao contrário que ouves e a app inverte a tua tentativa: se acertaste, sais a cantar a música a sério. Pontua o quão perto chegaste.

• Duas interfaces: botões grandes e simples, ou a onda completa com ciclo, velocidade e tom
• Guarda as tuas melhores takes e volta a elas

PRIVADO POR DESENHO

Tudo acontece neste dispositivo. As tuas gravações, as tuas takes e as tuas dobragens exportadas nunca saem daqui: sem conta, sem registo, sem anúncios e sem nada para enviar. A app recolhe estatísticas de utilização anónimas para saber o que construir a seguir, nunca o conteúdo de uma gravação.

Grátis. Sem subscrição, sem compras dentro da app, sem nada para desbloquear.

Feito na Suíça. Feito com cuidado em Zurique.""",
    release_notes="""Dobragem de Cena — o segundo jogo.

• Duas cenas originais incluídas, para haver algo para dobrar assim que abres
• Importa mais: uma pasta ou um .zip de pack a partir de Ficheiros, AirDrop ou qualquer folha de partilha
• Grava a tua voz falha a falha sobre a cena, com a onda original por baixo da tua e uma barra de ritmo que te avisa quando te estás a alongar
• Ouve a original nos auscultadores enquanto gravas
• Vê a original, ouve a tua dobragem ou exporta a cena terminada em vídeo e partilha-a
• Os diálogos sobrepostos agora misturam-se bem: duas personagens a falar ao mesmo tempo somam correctamente em vez de se taparem

O Reverso já fala francês, italiano, japonês e português.

Nova introdução que te mostra os dois jogos antes de te pedir o microfone.""",
)

# ---------------------------------------------------------------------------
# ja
# ---------------------------------------------------------------------------
JA = dict(
    subtitle="映画のシーンを自分の声でアフレコ",
    keywords=["choicer", "voicer", "dubbing", "voiceover", "アフレコ", "吹き替え",
              "声真似", "ものまね", "逆再生", "逆さま", "替え歌", "カラオケ", "アニメ",
              "マイク", "声優", "ボイス"],
    promotional_text=(
        "1.3.0の新機能「映画アフレコ」。オリジナルのシーンを2つ収録。シーンに合わせて一行ずつ自分の声を録音し、仕上げた動画を書き出して共有できます。7言語に対応。"
    ),
    description="""Reversoは、声で遊ぶ2つのゲームがひとつになったアプリです。必要なのはマイクだけ。

映画アフレコ

シーンを読み込んで、自分でアフレコしましょう。Reversoが元のセリフを再生し、映像とテキスト、そして合わせるべき長さを表示します。あとは自分のテイクを録音するだけ。元の波形が自分の波形の下に重なって表示されるので、入りが早かったところ、急ぎすぎたところ、間が空いたところがひと目でわかります。

• 一行ずつ、自分のペースで。いつでも中断して続きから再開できます
• 録音中に元の演技をヘッドフォンで聞くこともできます
• キャラクターごとに色分けされ、誰が話しているかが常にわかります
• 元の長さを超えると琥珀色に変わるペースバー
• オリジナルを観る、自分のアフレコを聴く、シーン全体を動画として書き出す
• 重なったセリフは別レーンでミックスされるので、二人が同時に話す場面もそのとおりに聞こえます

仕上がると、Reversoは自分の声が入ったシーンをレンダリングし、共有できる動画として渡してくれます。

まずは収録済みの2シーンから

Reversoには、このアプリのために書き下ろしたオリジナルのシーンが2つ入っています。キャラクターもセリフも声も映像も、すべて自前です。モードを開いた瞬間から、アフレコできるものがあります。

その先は自由に増やしてください。Reversoは映画を一切含みません。ホストも提供もしていません。アフレコ用のパックは他のプレイヤーが制作・共有しているものです。好きなものをダウンロードし、「ファイル」やAirDrop、共有シートからフォルダまたは.zipを読み込んでください。アフレコする素材の権利については、ご自身の責任となります。

逆再生シンギング

こちらが元からあるゲームです。曲を録音するとReversoがそれを逆再生します。聞こえた逆さまの音をそのとおりに歌い、アプリがその録音をもう一度ひっくり返す。うまくいっていれば、本物の曲を歌っているように聞こえます。どれだけ近づけたかを採点します。

• 2つのインターフェース：大きなボタンのシンプル表示か、ループ・速度・ピッチまで揃った波形表示か
• お気に入りのテイクは保存して、あとから聴き返せます

プライバシーは設計から

すべてこの端末の中で完結します。録音も、テイクも、書き出したアフレコ動画も、端末から出ることはありません。アカウントも登録も広告もなく、アップロードするものもありません。次に何を作るかの判断のため匿名の利用統計は取得しますが、録音の中身は決して送信されません。

無料です。サブスクリプションも、アプリ内課金も、解除するものもありません。

スイス製。チューリッヒで丁寧に作りました。""",
    release_notes="""映画アフレコ — 2つ目のゲームが登場しました。

• オリジナルのシーンを2つ収録。開いてすぐにアフレコを始められます
• 追加も自由：「ファイル」やAirDrop、共有シートからパックのフォルダまたは.zipを読み込めます
• シーンに合わせて一行ずつ自分の声を録音。元の波形が自分の波形の下に重なり、長くなりすぎるとペースバーが知らせます
• 録音中に元の演技をヘッドフォンで確認できます
• オリジナルを観る、自分のアフレコを聴く、仕上げたシーンを動画として書き出して共有する
• 重なったセリフのミックスを修正しました。二人が同時に話す場面でも、片方がかき消されることなく正しく重なります

Reversoがフランス語・イタリア語・日本語・ポルトガル語に対応しました。

マイクの許可を求める前に、両方のゲームを紹介する新しいオンボーディングになりました。""",
)

LOCALES = {"en-US": EN, "es-ES": ES, "ca": CA, "fr-FR": FR,
           "it": IT, "ja": JA, "pt-PT": PT}


def main() -> int:
    failures = []
    for locale, data in LOCALES.items():
        d = ROOT / locale
        d.mkdir(parents=True, exist_ok=True)

        fields = {
            "name": NAME,
            "subtitle": data["subtitle"],
            "keywords": ",".join(data["keywords"]),
            "promotional_text": data["promotional_text"],
            "description": data["description"],
            "release_notes": data["release_notes"],
            **URLS,
        }

        for field, value in fields.items():
            (d / f"{field}.txt").write_text(value.rstrip("\n") + "\n", encoding="utf-8")
            limit = LIMITS.get(field)
            if limit and len(value) > limit:
                failures.append(f"{locale}/{field}: {len(value)}/{limit}")

        print(f"{locale:>6}  name {len(fields['name']):>2}/30   "
              f"subtitle {len(fields['subtitle']):>2}/30   "
              f"keywords {len(fields['keywords']):>3}/100   "
              f"promo {len(fields['promotional_text']):>3}/170   "
              f"desc {len(fields['description']):>4}/4000   "
              f"notes {len(fields['release_notes']):>4}/4000")

    if failures:
        print("\nOVER LIMIT:", file=sys.stderr)
        for f in failures:
            print("  " + f, file=sys.stderr)
        return 1
    print("\nAll fields within App Store Connect limits.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

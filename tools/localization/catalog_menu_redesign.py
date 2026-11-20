# -*- coding: utf-8 -*-
"""Redesigned menu panel: status card, trigger list, duration chips, guard
tiles, section-based Customize Menu, and the panel status model in Core.

Each value lists the 14 shipping languages in LANGS order. A few keys reuse a
translation that already ships in the other table (see SHARED_*).
"""

LANGS = ["hu", "es", "fr", "de", "zh-Hans", "it", "ja", "ko", "ru", "pt-BR", "tr", "pl", "uk", "zh-Hant"]


def _table(rows):
    return {key: dict(zip(LANGS, values)) for key, values in rows.items()}


APP = _table({
    "held for": ("tartva ennyi ideje", "activo desde hace", "maintenu depuis", "gehalten seit", "已保持", "attivo da", "維持中", "유지 시간", "удерживается", "mantido há", "tutuluyor", "utrzymywane od", "утримується", "已保持"),
    "awake for": ("ébren ennyi ideje", "despierto desde hace", "éveillé depuis", "wach seit", "已唤醒", "sveglio da", "起動中", "깨어 있는 시간", "не спит", "acordado há", "uyanık", "aktywny od", "не спить", "已喚醒"),
    "sleeps in": ("alvás ennyi múlva", "duerme en", "veille dans", "schläft in", "将在此后睡眠", "dorme tra", "スリープまで", "잠자기까지", "уснёт через", "dorme em", "uyku için kalan", "uśpienie za", "засне через", "將於此後睡眠"),
    "Cursor warp": ("Kurzorugrás", "Salto del cursor", "Saut du curseur", "Cursor-Sprung", "光标跳转", "Salto del cursore", "カーソルワープ", "커서 워프", "Сдвиг курсора", "Salto do cursor", "İmleç sıçraması", "Skok kursora", "Зсув курсора", "游標跳轉"),
    "F15 key": ("F15 billentyű", "Tecla F15", "Touche F15", "F15-Taste", "F15 键", "Tasto F15", "F15 キー", "F15 키", "Клавиша F15", "Tecla F15", "F15 tuşu", "Klawisz F15", "Клавіша F15", "F15 鍵"),
    "Shift key": ("Shift billentyű", "Tecla Mayús", "Touche Maj", "Umschalttaste", "Shift 键", "Tasto Maiusc", "Shift キー", "Shift 키", "Клавиша Shift", "Tecla Shift", "Shift tuşu", "Klawisz Shift", "Клавіша Shift", "Shift 鍵"),
    "Pervigil: paused": ("Pervigil: szüneteltetve", "Pervigil: en pausa", "Pervigil : en pause", "Pervigil: pausiert", "Pervigil：已暂停", "Pervigil: in pausa", "Pervigil: 一時停止中", "Pervigil: 일시 정지됨", "Pervigil: приостановлено", "Pervigil: em pausa", "Pervigil: duraklatıldı", "Pervigil: wstrzymano", "Pervigil: призупинено", "Pervigil：已暫停"),
    "Always shown": ("Mindig látható", "Siempre visible", "Toujours affiché", "Immer sichtbar", "始终显示", "Sempre visibile", "常に表示", "항상 표시", "Показывается всегда", "Sempre visível", "Her zaman gösterilir", "Zawsze widoczne", "Завжди показано", "始終顯示"),
    "Compact strip": ("Kompakt sáv", "Franja compacta", "Bandeau compact", "Kompakte Leiste", "紧凑条", "Barra compatta", "コンパクト表示", "간결한 막대", "Компактная полоса", "Faixa compacta", "Kompakt şerit", "Kompaktowy pasek", "Компактна смуга", "精簡條"),
    "Full panel": ("Teljes panel", "Panel completo", "Panneau complet", "Volles Feld", "完整面板", "Pannello completo", "フルパネル", "전체 패널", "Полная панель", "Painel completo", "Tam panel", "Pełny panel", "Повна панель", "完整面板"),
    "Sections": ("Szakaszok", "Secciones", "Sections", "Bereiche", "分区", "Sezioni", "セクション", "섹션", "Разделы", "Seções", "Bölümler", "Sekcje", "Розділи", "區塊"),
    "Show, hide, or reorder whole sections. The status card always stays on top.": (
        "Teljes szakaszok megjelenítése, elrejtése vagy átrendezése. Az állapotkártya mindig felül marad.",
        "Muestra, oculta o reordena secciones completas. La tarjeta de estado siempre queda arriba.",
        "Affichez, masquez ou réorganisez des sections entières. La carte d’état reste toujours en haut.",
        "Ganze Bereiche ein- oder ausblenden oder neu anordnen. Die Statuskarte bleibt immer oben.",
        "显示、隐藏或重新排列整个分区。状态卡片始终位于顶部。",
        "Mostra, nascondi o riordina intere sezioni. La scheda di stato resta sempre in alto.",
        "セクション単位で表示、非表示、並べ替えができます。ステータスカードは常に一番上です。",
        "섹션 단위로 표시, 숨기기, 순서 변경을 할 수 있습니다. 상태 카드는 항상 맨 위에 있습니다.",
        "Показывайте, скрывайте и меняйте порядок целых разделов. Карточка состояния всегда остаётся сверху.",
        "Mostre, oculte ou reordene seções inteiras. O cartão de status fica sempre no topo.",
        "Bölümlerin tamamını gösterin, gizleyin veya yeniden sıralayın. Durum kartı her zaman en üstte kalır.",
        "Pokazuj, ukrywaj lub zmieniaj kolejność całych sekcji. Karta stanu zawsze pozostaje na górze.",
        "Показуйте, приховуйте або змінюйте порядок цілих розділів. Картка стану завжди залишається вгорі.",
        "顯示、隱藏或重新排列整個區塊。狀態卡片一律位於頂端。"),
    "Compact panel": ("Kompakt panel", "Panel compacto", "Panneau compact", "Kompaktes Feld", "紧凑面板", "Pannello compatto", "コンパクトパネル", "간결한 패널", "Компактная панель", "Painel compacto", "Kompakt panel", "Kompaktowy panel", "Компактна панель", "精簡面板"),
    "More": ("Továbbiak", "Más", "Plus", "Mehr", "更多", "Altro", "その他", "더 보기", "Ещё", "Mais", "Daha fazla", "Więcej", "Більше", "更多"),
    "%@ options": ("%@ beállításai", "Opciones de %@", "Options de %@", "Optionen für %@", "%@选项", "Opzioni di %@", "%@ のオプション", "%@ 옵션", "Параметры: %@", "Opções de %@", "%@ seçenekleri", "Opcje: %@", "Параметри: %@", "%@選項"),
    "Battery Guard": ("Akkuvédelem", "Protección de batería", "Protection batterie", "Akkuschutz", "电池保护", "Protezione batteria", "バッテリー保護", "배터리 보호", "Защита батареи", "Proteção da bateria", "Pil Koruması", "Ochrona baterii", "Захист батареї", "電池保護"),
    "Charge %d%%": ("Töltöttség: %d%%", "Carga: %d%%", "Charge : %d%%", "Ladung %d%%", "电量 %d%%", "Carica %d%%", "残量 %d%%", "충전량 %d%%", "Заряд %d%%", "Carga de %d%%", "Şarj %d%%", "Naładowanie %d%%", "Заряд %d%%", "電量 %d%%"),
    "Charge %d%%, plugged in": ("Töltöttség: %d%%, csatlakoztatva", "Carga: %d%%, conectado", "Charge : %d%%, branché", "Ladung %d%%, angeschlossen", "电量 %d%%，已接通电源", "Carica %d%%, collegato", "残量 %d%%、電源接続中", "충전량 %d%%, 전원 연결됨", "Заряд %d%%, подключено к сети", "Carga de %d%%, na tomada", "Şarj %d%%, prize takılı", "Naładowanie %d%%, podłączono", "Заряд %d%%, підключено до мережі", "電量 %d%%，已接上電源"),
    "Closed Lid": ("Csukott fedél", "Tapa cerrada", "Capot fermé", "Geschlossener Deckel", "合盖", "Coperchio chiuso", "ふたを閉じる", "덮개 닫힘", "Закрытая крышка", "Tampa fechada", "Kapak kapalı", "Zamknięta pokrywa", "Закрита кришка", "闔蓋"),
    "Never Sleep": ("Soha nem alszik", "Nunca dormir", "Jamais en veille", "Nie schlafen", "永不睡眠", "Mai in stop", "スリープしない", "잠자기 안 함", "Без сна", "Nunca repousar", "Hiç uyuma", "Bez usypiania", "Без сну", "永不睡眠"),
    "Options": ("Beállítások", "Opciones", "Options", "Optionen", "选项", "Opzioni", "オプション", "옵션", "Параметры", "Opções", "Seçenekler", "Opcje", "Параметри", "選項"),
    "Sleeps below %d%%": ("%d%% alatt alszik", "Reposa por debajo del %d%%", "Veille sous %d%%", "Schläft unter %d%%", "低于 %d%% 时睡眠", "Stop sotto il %d%%", "%d%% 未満でスリープ", "%d%% 미만에서 잠자기", "Сон ниже %d%%", "Repousa abaixo de %d%%", "%d%% altında uyur", "Usypia poniżej %d%%", "Сон нижче %d%%", "低於 %d%% 時睡眠"),
    "Stay Active": ("Aktív marad", "Seguir activo", "Rester actif", "Aktiv bleiben", "保持活跃", "Resta attivo", "アクティブ維持", "활성 유지", "Активность", "Manter ativo", "Etkin kal", "Aktywność", "Активність", "保持活動"),
    "Change to": ("Módosítás erre", "Cambiar a", "Changer pour", "Ändern auf", "更改为", "Cambia in", "変更", "변경", "Изменить на", "Mudar para", "Şuna değiştir", "Zmień na", "Змінити на", "變更為"),
    "Custom…": ("Egyéni…", "Personalizar…", "Personnalisé…", "Eigene…", "自定…", "Personalizzato…", "カスタム…", "사용자 지정…", "Своё…", "Personalizado…", "Özel…", "Własne…", "Власне…", "自訂…"),
    "Keep awake for": ("Ébren tartás ennyi ideig", "Mantener despierto durante", "Garder éveillé pendant", "Wach halten für", "保持唤醒时长", "Tieni sveglio per", "スリープ防止の時間", "깨어 있게 유지할 시간", "Не засыпать в течение", "Manter acordado por", "Uyanık tutma süresi", "Nie usypiaj przez", "Не дати заснути протягом", "保持喚醒時長"),
    "Manual sets your triggers aside without changing them.": (
        "A Kézi mód félreteszi a triggereket, de nem módosítja őket.",
        "Manual deja a un lado tus disparadores sin cambiarlos.",
        "Manuel met vos déclencheurs de côté sans les modifier.",
        "Manuell stellt deine Auslöser zurück, ohne sie zu ändern.",
        "手动模式会暂时搁置触发条件，但不会更改它们。",
        "Manuale mette da parte gli attivatori senza modificarli.",
        "手動にするとトリガーは変更されずに一時的に無効になります。",
        "수동은 트리거를 변경하지 않고 잠시 보류합니다.",
        "Ручной режим откладывает триггеры, не меняя их.",
        "Manual deixa seus gatilhos de lado sem alterá-los.",
        "Manuel, tetikleyicilerinizi değiştirmeden bir kenara koyar.",
        "Tryb ręczny odkłada wyzwalacze na bok bez ich zmieniania.",
        "Ручний режим відкладає тригери, не змінюючи їх.",
        "手動模式會暫時擱置觸發條件，但不會變更它們。"),
    "Minutes": ("Perc", "Minutos", "Minutes", "Minuten", "分钟", "Minuti", "分", "분", "Минуты", "Minutos", "Dakika", "Minuty", "Хвилини", "分鐘"),
    "No limit": ("Korlát nélkül", "Sin límite", "Sans limite", "Ohne Limit", "无限制", "Senza limite", "無制限", "제한 없음", "Без ограничения", "Sem limite", "Sınırsız", "Bez limitu", "Без обмеження", "無限制"),
    "Until…": ("Eddig…", "Hasta…", "Jusqu’à…", "Bis…", "直到…", "Fino a…", "時刻まで…", "시각까지…", "До…", "Até…", "Saate kadar…", "Do…", "До…", "直到…"),
    "Update": ("Frissítés", "Actualizar", "Mettre à jour", "Aktualisieren", "更新", "Aggiorna", "更新", "업데이트", "Обновить", "Atualizar", "Güncelle", "Zaktualizuj", "Оновити", "更新"),
    "minutes": ("perc", "minutos", "minutes", "Minuten", "分钟", "minuti", "分", "분", "минут", "minutos", "dakika", "minut", "хвилин", "分鐘"),
    "End automation leases": ("Automatizálási bérletek befejezése", "Terminar concesiones de automatización", "Mettre fin aux baux d’automatisation", "Automatisierungs-Leases beenden", "结束自动化租约", "Termina le concessioni di automazione", "自動化リースを終了", "자동화 임대 종료", "Завершить аренды автоматизации", "Encerrar concessões de automação", "Otomasyon kiralarını sonlandır", "Zakończ dzierżawy automatyzacji", "Завершити оренди автоматизації", "結束自動化租約"),
    "End the paused session": ("A szüneteltetett munkamenet befejezése", "Terminar la sesión en pausa", "Terminer la session en pause", "Pausierte Sitzung beenden", "结束已暂停的会话", "Termina la sessione in pausa", "一時停止中のセッションを終了", "일시 정지된 세션 종료", "Завершить приостановленный сеанс", "Encerrar a sessão em pausa", "Duraklatılan oturumu sonlandır", "Zakończ wstrzymaną sesję", "Завершити призупинений сеанс", "結束已暫停的工作階段"),
    "Paused by battery guard": ("Az akkuvédelem szüneteltette", "En pausa por la protección de batería", "En pause par la protection batterie", "Vom Akkuschutz pausiert", "已被电池保护暂停", "In pausa per la protezione batteria", "バッテリー保護により一時停止中", "배터리 보호로 일시 정지됨", "Приостановлено защитой батареи", "Em pausa pela proteção da bateria", "Pil koruması tarafından duraklatıldı", "Wstrzymano przez ochronę baterii", "Призупинено захистом батареї", "已被電池保護暫停"),
    "Set triggers aside and let the Mac sleep": ("Triggerek félretétele, a Mac aludhat", "Dejar los disparadores a un lado y permitir que el Mac duerma", "Mettre les déclencheurs de côté et laisser le Mac se mettre en veille", "Auslöser zurückstellen und den Mac schlafen lassen", "搁置触发条件并让 Mac 睡眠", "Metti da parte gli attivatori e lascia dormire il Mac", "トリガーを一時無効にして Mac をスリープさせる", "트리거를 보류하고 Mac을 잠자기 상태로 두기", "Отложить триггеры и разрешить Mac заснуть", "Deixar os gatilhos de lado e permitir que o Mac repouse", "Tetikleyicileri bir kenara koy ve Mac’in uyumasına izin ver", "Odłóż wyzwalacze i pozwól Macowi zasnąć", "Відкласти тригери й дозволити Mac заснути", "擱置觸發條件並讓 Mac 睡眠"),
    "Show full panel": ("Teljes panel megjelenítése", "Mostrar panel completo", "Afficher le panneau complet", "Volles Feld anzeigen", "显示完整面板", "Mostra pannello completo", "フルパネルを表示", "전체 패널 보기", "Показать полную панель", "Mostrar painel completo", "Tam paneli göster", "Pokaż pełny panel", "Показати повну панель", "顯示完整面板"),
    "Stop keeping awake": ("Ébren tartás leállítása", "Dejar de mantener despierto", "Arrêter de garder éveillé", "Wachhalten beenden", "停止保持唤醒", "Smetti di tenere sveglio", "スリープ防止を停止", "깨어 있게 유지 중지", "Прекратить удерживать от сна", "Parar de manter acordado", "Uyanık tutmayı durdur", "Przestań utrzymywać w czuwaniu", "Припинити утримувати від сну", "停止保持喚醒"),
    "Time left": ("Hátralévő idő", "Tiempo restante", "Temps restant", "Verbleibende Zeit", "剩余时间", "Tempo rimanente", "残り時間", "남은 시간", "Осталось времени", "Tempo restante", "Kalan süre", "Pozostały czas", "Залишилось часу", "剩餘時間"),
    "%d of %d": ("%d / %d", "%d de %d", "%d sur %d", "%d von %d", "%d / %d", "%d di %d", "%d / %d", "%d / %d", "%d из %d", "%d de %d", "%d / %d", "%d z %d", "%d з %d", "%d / %d"),
    "%d working": ("%d dolgozik", "%d trabajando", "%d au travail", "%d arbeiten", "%d 个工作中", "%d al lavoro", "%d 件作業中", "%d개 작업 중", "работает: %d", "%d trabalhando", "%d çalışıyor", "pracuje: %d", "працює: %d", "%d 個工作中"),
    "(%@ grace)": ("(%@ türelmi idő)", "(%@ de gracia)", "(%@ de répit)", "(%@ Nachlauf)", "（宽限 %@）", "(%@ di tolleranza)", "（猶予 %@）", "(유예 %@)", "(отсрочка %@)", "(%@ de tolerância)", "(%@ ek süre)", "(%@ karencji)", "(відтермінування %@)", "（寬限 %@）"),
    "Awake while all are met": ("Ébren, amíg mind teljesül", "Despierto mientras se cumplan todas", "Éveillé tant que toutes sont remplies", "Wach, solange alle erfüllt sind", "全部满足时保持唤醒", "Sveglio finché sono tutte soddisfatte", "すべて満たされている間はスリープ防止", "모두 충족되는 동안 깨어 있음", "Не спит, пока выполнены все", "Acordado enquanto todas forem atendidas", "Tümü karşılandıkça uyanık", "Czuwa, gdy wszystkie są spełnione", "Не спить, поки виконано всі", "全部符合時保持喚醒"),
    "Awake while any is met": ("Ébren, amíg bármelyik teljesül", "Despierto mientras se cumpla alguna", "Éveillé tant qu’une est remplie", "Wach, solange eine erfüllt ist", "任一满足时保持唤醒", "Sveglio finché una è soddisfatta", "いずれかが満たされている間はスリープ防止", "하나라도 충족되는 동안 깨어 있음", "Не спит, пока выполнено любое", "Acordado enquanto alguma for atendida", "Herhangi biri karşılandıkça uyanık", "Czuwa, gdy którykolwiek jest spełniony", "Не спить, поки виконано будь-який", "任一符合時保持喚醒"),
    "End all": ("Mind befejezése", "Terminar todas", "Tout terminer", "Alle beenden", "全部结束", "Termina tutte", "すべて終了", "모두 종료", "Завершить все", "Encerrar todas", "Tümünü sonlandır", "Zakończ wszystkie", "Завершити всі", "全部結束"),
    "End": ("Befejezés", "Terminar", "Terminer", "Beenden", "结束", "Termina", "終了", "종료", "Завершить", "Encerrar", "Sonlandır", "Zakończ", "Завершити", "結束"),
    "Lease, ends in %@": ("Bérlet, %@ múlva lejár", "Concesión, termina en %@", "Bail, se termine dans %@", "Lease, endet in %@", "租约，%@ 后结束", "Concessione, termina tra %@", "リース、残り %@", "임대, %@ 후 종료", "Аренда, закончится через %@", "Concessão, termina em %@", "Kira, %@ içinde biter", "Dzierżawa, kończy się za %@", "Оренда, завершиться через %@", "租約，%@ 後結束"),
    "Show %d more agents": ("További %d ügynök megjelenítése", "Mostrar %d agentes más", "Afficher %d agents de plus", "%d weitere Agenten anzeigen", "再显示 %d 个代理", "Mostra altri %d agenti", "ほかに %d 件のエージェントを表示", "에이전트 %d개 더 보기", "Показать ещё агентов: %d", "Mostrar mais %d agentes", "%d ajan daha göster", "Pokaż więcej agentów: %d", "Показати ще агентів: %d", "再顯示 %d 個代理"),
})

CORE = _table({
    "%@ is working": ("%@ dolgozik", "%@ está trabajando", "%@ travaille", "%@ arbeitet", "%@ 正在工作", "%@ sta lavorando", "%@ が作業中", "%@ 작업 중", "%@ работает", "%@ está trabalhando", "%@ çalışıyor", "%@ pracuje", "%@ працює", "%@ 正在工作"),
    "%d%% to go": ("még %d%%", "quedan %d%%", "encore %d%%", "noch %d%%", "还剩 %d%%", "ancora %d%%", "あと %d%%", "%d%% 남음", "осталось %d%%", "faltam %d%%", "%d%% kaldı", "zostało %d%%", "залишилось %d%%", "還剩 %d%%"),
    "%d%%, sleeps at %d%%": ("%d%%, %d%%-nál alszik", "%d%%, reposa al %d%%", "%d%%, veille à %d%%", "%d%%, schläft bei %d%%", "%d%%，%d%% 时睡眠", "%d%%, stop al %d%%", "%d%%、%d%% でスリープ", "%d%%, %d%%에서 잠자기", "%d%%, сон при %d%%", "%d%%, repousa em %d%%", "%d%%, %d%% olunca uyur", "%d%%, usypia przy %d%%", "%d%%, сон при %d%%", "%d%%，%d%% 時睡眠"),
    "Agents finished. Waiting before sleep.": ("Az ügynökök végeztek. Várakozás az alvás előtt.", "Los agentes terminaron. Esperando antes de reposar.", "Les agents ont terminé. Attente avant la veille.", "Agenten fertig. Warten vor dem Ruhezustand.", "代理已完成。睡眠前等待中。", "Agenti terminati. Attesa prima dello stop.", "エージェントが完了しました。スリープ前に待機中です。", "에이전트가 완료되었습니다. 잠자기 전 대기 중입니다.", "Агенты закончили. Ожидание перед сном.", "Os agentes terminaram. Aguardando antes de repousar.", "Ajanlar bitirdi. Uyumadan önce bekleniyor.", "Agenci skończyli. Oczekiwanie przed uśpieniem.", "Агенти завершили. Очікування перед сном.", "代理已完成。睡眠前等待中。"),
    "Battery %d%%. Sleeps at %d%%.": ("Akkumulátor: %d%%. %d%%-nál alszik.", "Batería al %d%%. Reposa al %d%%.", "Batterie à %d%%. Veille à %d%%.", "Akku %d%%. Schläft bei %d%%.", "电量 %d%%。%d%% 时睡眠。", "Batteria al %d%%. Stop al %d%%.", "バッテリー %d%%。%d%% でスリープします。", "배터리 %d%%. %d%%에서 잠자기.", "Батарея %d%%. Сон при %d%%.", "Bateria em %d%%. Repousa em %d%%.", "Pil %d%%. %d%% olunca uyur.", "Bateria %d%%. Usypia przy %d%%.", "Батарея %d%%. Сон при %d%%.", "電量 %d%%。%d%% 時睡眠。"),
    "Battery below %d%%.": ("Az akkumulátor %d%% alatt van.", "Batería por debajo del %d%%.", "Batterie sous %d%%.", "Akku unter %d%%.", "电量低于 %d%%。", "Batteria sotto il %d%%.", "バッテリーが %d%% 未満です。", "배터리가 %d%% 미만입니다.", "Заряд ниже %d%%.", "Bateria abaixo de %d%%.", "Pil %d%% altında.", "Bateria poniżej %d%%.", "Заряд нижче %d%%.", "電量低於 %d%%。"),
    "Below %d%%": ("%d%% alatt", "Por debajo del %d%%", "Sous %d%%", "Unter %d%%", "低于 %d%%", "Sotto il %d%%", "%d%% 未満", "%d%% 미만", "Ниже %d%%", "Abaixo de %d%%", "%d%% altında", "Poniżej %d%%", "Нижче %d%%", "低於 %d%%"),
    "Can sleep": ("Aludhat", "Puede reposar", "Peut se mettre en veille", "Kann schlafen", "可以睡眠", "Può andare in stop", "スリープ可能", "잠자기 가능", "Может заснуть", "Pode repousar", "Uyuyabilir", "Może zasnąć", "Може заснути", "可以睡眠"),
    "During sessions": ("Munkamenetek alatt", "Durante las sesiones", "Pendant les sessions", "Während Sitzungen", "会话期间", "Durante le sessioni", "セッション中", "세션 중", "Во время сеансов", "Durante as sessões", "Oturumlar sırasında", "Podczas sesji", "Під час сеансів", "工作階段期間"),
    "Held by your triggers": ("A triggereid tartják ébren", "Mantenido por tus disparadores", "Maintenu par vos déclencheurs", "Von deinen Auslösern gehalten", "由你的触发条件保持", "Tenuto dai tuoi attivatori", "トリガーにより維持中", "트리거가 유지 중", "Удерживается вашими триггерами", "Mantido pelos seus gatilhos", "Tetikleyicileriniz tutuyor", "Utrzymywane przez wyzwalacze", "Утримується вашими тригерами", "由你的觸發條件保持"),
    "Lease: %@": ("Bérlet: %@", "Concesión: %@", "Bail : %@", "Lease: %@", "租约：%@", "Concessione: %@", "リース: %@", "임대: %@", "Аренда: %@", "Concessão: %@", "Kira: %@", "Dzierżawa: %@", "Оренда: %@", "租約：%@"),
    "Lid can close": ("A fedél lecsukható", "Se puede cerrar la tapa", "Le capot peut être fermé", "Deckel kann zu", "可以合盖", "Il coperchio può essere chiuso", "ふたを閉じても大丈夫", "덮개를 닫아도 됨", "Крышку можно закрыть", "A tampa pode ser fechada", "Kapak kapatılabilir", "Można zamknąć pokrywę", "Кришку можна закрити", "可以闔蓋"),
    "No battery": ("Nincs akkumulátor", "Sin batería", "Pas de batterie", "Kein Akku", "无电池", "Nessuna batteria", "バッテリーなし", "배터리 없음", "Нет батареи", "Sem bateria", "Pil yok", "Brak baterii", "Немає батареї", "無電池"),
    "No time limit": ("Nincs időkorlát", "Sin límite de tiempo", "Sans limite de temps", "Ohne Zeitlimit", "无时间限制", "Senza limite di tempo", "時間制限なし", "시간 제한 없음", "Без ограничения", "Sem limite de tempo", "Süre sınırı yok", "Bez limitu czasu", "Без обмеження часу", "無時間限制"),
    "Agents finished": ("Az ügynökök végeztek", "Los agentes terminaron", "Agents terminés", "Agenten fertig", "智能体已完成", "Agenti terminati", "エージェントが完了", "에이전트 작업 완료", "Агенты закончили", "Agentes concluíram", "Ajanlar bitirdi", "Agenci skończyli", "Агенти завершили", "代理程式已完成"),
    "On a call": ("Hívásban", "En una llamada", "En appel", "Im Anruf", "通话中", "In chiamata", "通話中", "통화 중", "Идёт звонок", "Em uma chamada", "Görüşmede", "Trwa rozmowa", "Триває дзвінок", "通話中"),
    "On, dims when idle": ("Be, tétlenségnél halványul", "Activada, se atenúa si está inactiva", "Activé, s’assombrit si inactif", "An, dimmt bei Leerlauf", "开启，空闲时调暗", "Attivo, si attenua se inattivo", "オン、アイドル時に暗く", "켬, 유휴 시 어둡게", "Вкл., приглушается при простое", "Ativado, escurece quando ociosa", "Açık, boştayken kararır", "Wł., przyciemnia przy bezczynności", "Увімк., затемнюється під час бездіяльності", "開啟，閒置時調暗"),
    "Paused, %d%%": ("Szüneteltetve, %d%%", "En pausa, %d%%", "En pause, %d%%", "Pausiert, %d%%", "已暂停，%d%%", "In pausa, %d%%", "一時停止中、%d%%", "일시 정지됨, %d%%", "Приостановлено, %d%%", "Em pausa, %d%%", "Duraklatıldı, %d%%", "Wstrzymano, %d%%", "Призупинено, %d%%", "已暫停，%d%%"),
    "Plug in to keep going.": ("Csatlakoztasd a töltőt a folytatáshoz.", "Conecta el cargador para continuar.", "Branchez le Mac pour continuer.", "Schließe das Netzteil an, um weiterzumachen.", "接通电源以继续。", "Collega l’alimentatore per continuare.", "続けるには電源に接続してください。", "계속하려면 전원을 연결하세요.", "Подключите к сети, чтобы продолжить.", "Conecte à tomada para continuar.", "Devam etmek için prize takın.", "Podłącz zasilanie, aby kontynuować.", "Підключіть до мережі, щоб продовжити.", "接上電源以繼續。"),
    "Plug in to resume.": ("Csatlakoztasd a töltőt az újraindításhoz.", "Conecta el cargador para reanudar.", "Branchez le Mac pour reprendre.", "Schließe das Netzteil an, um fortzufahren.", "接通电源以恢复。", "Collega l’alimentatore per riprendere.", "再開するには電源に接続してください。", "다시 시작하려면 전원을 연결하세요.", "Подключите к сети, чтобы возобновить.", "Conecte à tomada para retomar.", "Sürdürmek için prize takın.", "Podłącz zasilanie, aby wznowić.", "Підключіть до мережі, щоб поновити.", "接上電源以恢復。"),
    "Plugged in": ("Csatlakoztatva", "Conectado", "Branché", "Angeschlossen", "已接通电源", "Collegato", "電源接続中", "전원 연결됨", "Подключено к сети", "Na tomada", "Prize takılı", "Podłączono", "Підключено до мережі", "已接上電源"),
    "Press the mark or pick a duration": ("Nyomd meg a jelet, vagy válassz időtartamot", "Pulsa la marca o elige una duración", "Appuyez sur la marque ou choisissez une durée", "Drücke das Zeichen oder wähle eine Dauer", "按下标志或选择时长", "Premi il logo o scegli una durata", "マークを押すか時間を選んでください", "마크를 누르거나 시간을 선택하세요", "Нажмите на знак или выберите длительность", "Pressione a marca ou escolha uma duração", "İşarete basın veya bir süre seçin", "Naciśnij znak lub wybierz czas", "Натисніть знак або виберіть тривалість", "按下標誌或選擇時長"),
    "Sleeps": ("Alszik", "Reposa", "En veille", "Schläft", "睡眠", "Va in stop", "スリープ", "잠자기", "Засыпает", "Repousa", "Uyur", "Usypia", "Засинає", "睡眠"),
    "Stays awake": ("Ébren marad", "Sigue despierto", "Reste éveillé", "Bleibt wach", "保持唤醒", "Resta sveglio", "スリープしない", "깨어 있음", "Не засыпает", "Fica acordado", "Uyanık kalır", "Nie usypia", "Не засинає", "保持喚醒"),
    "Stays on": ("Bekapcsolva marad", "Sigue encendida", "Reste allumé", "Bleibt an", "保持开启", "Resta acceso", "点灯したまま", "켜진 상태 유지", "Остаётся включённым", "Fica ligada", "Açık kalır", "Pozostaje włączony", "Залишається ввімкненим", "保持開啟"),
    "Stops at %@ tomorrow": ("Holnap %@-kor áll le", "Se detiene mañana a las %@", "S’arrête demain à %@", "Endet morgen um %@", "明天 %@ 停止", "Si ferma domani alle %@", "明日 %@ に停止", "내일 %@에 중지", "Остановится завтра в %@", "Para amanhã às %@", "Yarın %@ saatinde durur", "Zatrzyma się jutro o %@", "Зупиниться завтра о %@", "明天 %@ 停止"),
    "Stops at %@": ("%@-kor áll le", "Se detiene a las %@", "S’arrête à %@", "Endet um %@", "%@ 停止", "Si ferma alle %@", "%@ に停止", "%@에 중지", "Остановится в %@", "Para às %@", "%@ saatinde durur", "Zatrzyma się o %@", "Зупиниться о %@", "%@ 停止"),
    "Watching %d triggers": ("%d trigger figyelése", "Vigilando %d disparadores", "Surveillance de %d déclencheurs", "Beobachte %d Auslöser", "正在监视 %d 个触发条件", "Monitoraggio di %d attivatori", "%d 件のトリガーを監視中", "트리거 %d개 감시 중", "Отслеживается триггеров: %d", "Observando %d gatilhos", "%d tetikleyici izleniyor", "Obserwowane wyzwalacze: %d", "Відстежується тригерів: %d", "正在監看 %d 個觸發條件"),
    "Watching 1 trigger": ("1 trigger figyelése", "Vigilando 1 disparador", "Surveillance de 1 déclencheur", "Beobachte 1 Auslöser", "正在监视 1 个触发条件", "Monitoraggio di 1 attivatore", "1 件のトリガーを監視中", "트리거 1개 감시 중", "Отслеживается 1 триггер", "Observando 1 gatilho", "1 tetikleyici izleniyor", "Obserwowany 1 wyzwalacz", "Відстежується 1 тригер", "正在監看 1 個觸發條件"),
})

# Keys whose translations already ship in the other table: copied at merge
# time so the two never drift apart.
SHARED_FROM_APP_TO_CORE = ["Awake", "Off", "Paused", "Running hot, letting the Mac cool down"]
SHARED_FROM_CORE_TO_APP = ["AI agent working"]

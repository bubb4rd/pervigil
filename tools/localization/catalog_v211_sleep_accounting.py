# -*- coding: utf-8 -*-
"""Sleep stand-down and exit accounting decision-log strings."""

LANGS = ["hu", "es", "fr", "de", "zh-Hans", "it", "ja", "ko", "ru", "pt-BR", "tr", "pl", "uk", "zh-Hant"]


def _table(rows):
    return {key: dict(zip(LANGS, values)) for key, values in rows.items()}


APP = _table({
    "Pervigil stopped unexpectedly": (
        "A Pervigil váratlanul leállt",
        "Pervigil se detuvo inesperadamente",
        "Pervigil s’est arrêté de façon inattendue",
        "Pervigil wurde unerwartet beendet",
        "Pervigil 意外停止",
        "Pervigil si è interrotto inaspettatamente",
        "Pervigil が予期せず停止",
        "Pervigil이 예기치 않게 중지됨",
        "Pervigil неожиданно остановился",
        "O Pervigil parou inesperadamente",
        "Pervigil beklenmedik şekilde durdu",
        "Pervigil nieoczekiwanie się zatrzymał",
        "Pervigil неочікувано зупинився",
        "Pervigil 意外停止",
    ),
})

CORE = _table({
    "Paused, the Mac went to sleep": (
        "Szüneteltetve, a Mac alvó módba lépett",
        "En pausa, el Mac entró en reposo",
        "En pause, le Mac s’est mis en veille",
        "Pausiert, der Mac ist in den Ruhezustand gegangen",
        "已暂停，Mac 已进入睡眠",
        "In pausa, il Mac è andato in stop",
        "一時停止、Mac がスリープ",
        "일시 정지됨, Mac이 잠자기 상태로 전환됨",
        "Приостановлено, Mac перешёл в режим сна",
        "Pausado, o Mac entrou em repouso",
        "Duraklatıldı, Mac uyku moduna geçti",
        "Wstrzymano, Mac przeszedł w stan uśpienia",
        "Призупинено, Mac перейшов у режим сну",
        "已暫停，Mac 已進入睡眠",
    ),
    "Resumed after sleep": (
        "Folytatva alvás után",
        "Reanudado tras el reposo",
        "Reprise après la veille",
        "Nach dem Ruhezustand fortgesetzt",
        "睡眠后已恢复",
        "Ripreso dopo lo stop",
        "スリープ後に再開",
        "잠자기 후 재개됨",
        "Возобновлено после сна",
        "Retomado após o repouso",
        "Uykudan sonra devam edildi",
        "Wznowiono po uśpieniu",
        "Поновлено після сну",
        "睡眠後已恢復",
    ),
    "Pervigil quit": (
        "A Pervigil kilépett",
        "Pervigil se cerró",
        "Pervigil a été quitté",
        "Pervigil wurde beendet",
        "Pervigil 已退出",
        "Pervigil è stato chiuso",
        "Pervigil を終了",
        "Pervigil 종료됨",
        "Pervigil закрыт",
        "O Pervigil foi encerrado",
        "Pervigil kapatıldı",
        "Zamknięto Pervigil",
        "Pervigil закрито",
        "Pervigil 已結束",
    ),
})

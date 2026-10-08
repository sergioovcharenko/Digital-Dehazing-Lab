# Digital Dehazing — каталог алгоритмів і вихідних файлів

**Оновлено:** 8 жовтня 2026. **Мета:** повна інвентаризація оригінальних напрацювань для Cursor, без втрати історичних реалізацій. Цей каталог **не** є звітом, що всі перелічені алгоритми працюють у QGC APK. Жоден із описаних кодів не дозволено використовувати для підміни бази `QGC_4.4_PRESERVED(1).zip`.

## I. Нинішній основний репозиторій

**Основний проєкт**: https://github.com/sergioovcharenko/Digital-Dehazing-Lab

| Назва | Вихідний файл | Стан |
|---|---|---|
| PHOTO DCP / Strong DCP | `classic-dcp.js` → `dehazeStrongDCP()` | CPU/JS реалізація для фото |
| LIVE DCP | `classic-dcp.js` → `dehazeLiveDCP()` | CPU/JS реалізація для відеокадрів, із кешуванням розрахунків |
| FAST DCP preview | `multimode-test/index.html` | Браузерний прототип; окремий Android native FAST теж є в архівному коді нижче |
| CAP preview | `multimode-test/index.html` | Браузерний CAP-подібний прототип; окремий Android CAP реалізовано історично |
| CLAHE-L preview | `multimode-test/index.html` | Браузерний прототип |
| Retinex preview | `multimode-test/index.html` | Браузерний прототип |
| Adaptive + Detail preview | `multimode-test/index.html` | Браузерний складений профіль |
| AUTO preview | `multimode-test/index.html` | Евристичне керування силою, не самостійна модель |
| WebL / Adaptive MAX | `index.html` та його підключені скрипти | Вебрежим; визначити точний актуальний WebGL-фрагмент перед портом |
| EDN-GTM NH-HAZE TFJS | `models/edn-gtm/nhhaze-192x320/model.json` + `group1-shard*of24.bin` | Збережена TFJS-модель; потрібен runtime та перевірка inference |
| EDN-GTM NH-HAZE TFLite lite | `models/edn-gtm/nhhaze-192x320-lite/model.tflite` | Збережена інша TFLite-версія; не прирівнювати до 512×512 FP16 |

## II. Історичний Android-код — **не загубити!**

**Архівне джерело**: https://github.com/sergioovcharenko/Dehaze-Web/tree/c48e1aef373f2def6bb4c3d0b95a8a21ce6d3653/android-lab3/engine/src/main/java/ua/dehaze/live

**Важливо:** користувач визначив `Digital-Dehazing-Lab` як актуальний проєкт. `Dehaze-Web` використовується тут **лише як фіксований історичний знімок вихідних алгоритмів**, а не як нова основна репозиторія чи база APK.

| Алгоритм або компонент | Файл у `android-lab3/engine/src/main/java/ua/dehaze/live/` | Примітка |
|---|---|---|
| CLASSIC MAX — CPU snapshot | `ClassicSnapshot.java` | Інтерпретація попереднього LAB2 гібридного shader; `flags=63` означає ввімкнені етапи в попередніх тестах |
| **BC/CR** — Boundary Constraint + Contextual Regularization | `BcDehaze.java` | Реалізація атмосферного світла, boundary transmission, 8 Kirsch direction, контекстної регуляризації, recovery |
| **CAP** — Color Attenuation Prior | `LightDehaze.java` (cap=true) | Окрема детермінована реалізація, відмінна від браузерного preview |
| **FAST DCP** | `LightDehaze.java` (cap=false) | Легкий DCP з обмеженою картою, guided refinement, без важких постфільтрів |
| Керування OFF і алгоритмами | `AntiFogEngine.java` | Розділяє обробку від UI; маркери ORIGINAL/CLASSIC/BC_CR/AI/CAP/FAST |
| AUTO SELECT — політика перемикання | `AutoPolicy.java` | Гістерезис і паузи між переходами |
| AUTO SELECT — запуски кандидатів | `AutoProcessing.java` | Порівнює результати в окремому worker |
| AUTO SELECT — метрика | `AutoQuality.java` | Евристика якості, **не** ground-truth |
| AUTO strength | `AutoStrength.java` | Інтенсивність |
| Рушій і вибір режимів | `Lab3Processor.java` | Мапа CLASSIC, BC/CR, DehazeFormer-T, CAP, FAST |
| DehazeFormer-T adapter | `NeuralDehaze.java` | ONNX Runtime adapter, **не доказ наявності ваг або успішного inference** |
| Multi-stage map generation | `VideoDehazeProcessor.java` | DCP/transmission, LUT/фільтри |
| Піксельні перетворення | `ImagePlanes.java` | Допоміжний код |

Додатковий GPU/DCP pipeline (історична версія, той самий репозиторій):
- `android-lab2/app/src/main/java/ua/dehaze/live/SplitRenderer.java`: shader із DCP, CLAHE, Retinex, Fusion.
- `android-lab2/app/src/main/java/ua/dehaze/live/VideoDehazeProcessor.java`: LUT, transmission/обчислення для shader.
- `android-max/app/src/main/java/ua/dehaze/live/SplitRenderer.java`: Adaptive Object MAX.
- `android-video-max/app/src/main/java/ua/dehaze/live/SplitRenderer.java`: варіант Video MAX.

## III. Сімейство власного Adaptive WebGL / WebL

Історичні вихідні файли в `Dehaze-Web` (поточна гілка містить попередні версії, але це **не** заміна актуального репозиторію):
- `video-dehaze-adaptive-v17.js`
- `video-dehaze-adaptive-v18.js`
- `video-dehaze-adaptive-v19.js`
- `video-dehaze-adaptive-v20.js`
- `video-dehaze-adaptive-v21.js`
- `video-dehaze.js`
- `dehaze-dcp-adaptive-v6.js`

Це **версії та варіанти одного сімейства**, а не автоматично сім окремих незалежних алгоритмів. Перевірити, яка версія реально підключена до останнього стабільного WebL, порівняти контрольні кадри й лише тоді обирати порт.

## IV. Внутрішні математичні етапи (не плутати з незалежними режимами меню)

- Dark Channel Prior / Multi-scale DCP.
- Atmospheric Light Estimation.
- Transmission Map.
- Guided / Edge-aware Refinement.
- Local Contrast Enhancement.
- Detail / Weak-structure Recovery.
- CLAHE / luminance LUT.
- Retinex.
- Adaptive Denoise / noise protection.
- Temporal Stabilization / flicker suppression.
- Image Fusion.
- Color / White balance / Gamma safeguards.
- AUTO strength and scene DAY / NIGHT.
- AUTO SELECT (порівняння алгоритмів із затримкою та гістерезисом).

**Не заявляти ці компоненти як 14 окремих програм чи 14 independent algorithms:** здебільшого це етапи кількох композиційних алгоритмів.

## V. Нейромережеві моделі — окрема група

З попереднього `Digital-Dehazing-APK-Spec.md` від 7 жовтня 2026 перелічені п'ять отриманих `.h5` ваг EDN-GTM:
1. `ihaze_generator_in512_ep_185_loss26.h5` — I-HAZE.
2. `ohaze_generator_in512_ep120_loss125.h5` — O-HAZE.
3. `densehaze_generator_in512_ep85_loss227.h5` — Dense-HAZE.
4. `nhhaze_generator_in512_ep160_loss297.h5` — NH-HAZE.
5. `sotsoutdoor_generator_in512_ep155_loss4.h5` — SOTS-Outdoor.

Джерело архітектури: https://github.com/tranleanh/edn-gtm ; варіант для конвертацій: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/277_EDN-GTM .

**Стан:** із п'яти H5 ваг на попередній стадії валидації було повідомлено, що всі ваги читаються, NH-HAZE конвертована в TFLite FP16; повна числова перевірка inference та інтеграція всіх 5 в APK не доведені. Оригінальні H5 **не знайдені в дереві поточного GitHub** — їх треба передати Cursor окремо або перевірити доступні локальні файли. Наявний на GitHub TFLite `nhhaze-192x320-lite` — інша конкретна версія.

**AIDTransformer, DehazeFormer / DehazeFormer-T, Dehaze-Attention:** попередньо розглядалися; вони **не входили до визначеної п'ятірки EDN-GTM** та не мають підтвердженої працездатної офлайн-інтеграції. У Android Lab3 є adapter `NeuralDehaze.java` для DehazeFormer-T; відсутність відповідної моделі ONNX не дозволяє позначати його робочим.

## VI. Еталонні перевірки

Попередній тест `Digital-Dehazing-Preliminary-Comparison.html` (7.10.2026): 6 обробників × 6 кадрів, але без повного відео, без камерного GPU тесту та без коректного висновку «найкращий алгоритм». Старий CLASSIC, BC/CR, CAP, FAST, PHOTO DCP, LIVE DCP були реально запущені на збережених кадрах. WebL/Adaptive MAX та AI моделі в цей тест не входили. Не оголошувати рейтинг AutoQuality доказом кращого алгоритму.

## VII. Інструкція для Cursor

1. Вважати `QGC_4.4_PRESERVED(1).zip` **єдиним вихідним APK**. Нічого штатного не міняти, окрім технічно неминучих мінімальних змін для інтерфейсу та обробки.
2. Перш ніж почати, скласти таблицю «режим → точний файл/commit → залежності → ступінь готовності → тест». Жодну назву в меню не створювати без справжнього коду.
3. Мапа меню: `OFF`; окремий `AUTO SELECT`; `Adaptive WebGL/WebL`; `CLASSIC MAX`; `BC/CR`; `PHOTO DCP`; `LIVE DCP`; `FAST DCP`; `CAP`; `CLAHE`; `RETINEX`; `Fusion/Adaptive Object`; 5 EDN-GTM профілів в окремій тестовій групі.
4. `DCP BALANCED`/`STRONG`, `LOW`/`MEDIUM`/`HIGH`, `DAY`/`NIGHT` — **пресети або параметри**, не додаткові незалежні моделі.
5. Не включати AIDTransformer/DehazeFormer/Dehaze-Attention до гарантовано робочих алгоритмів без валідних ваг і реального тесту.
6. Спочатку збереження оригінального відео, UI та OFF; потім окремі алгоритми, діагностика і тестування на планшеті без польоту. Не стверджувати, що APK існує, доки не зібрано та не підписано його.


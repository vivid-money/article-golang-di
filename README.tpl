# Методы организации DI и жизненного цикла приложения в GO

Есть несколько вещей, которыми можно заниматься вечно: смотреть на огонь, фиксить баги в легаси-коде и, конечно, говорить о DI - и всё равно нет-нет, да и будешь сталкиваться со странными зависимостями в очередном приложении.
В контексте языка GO, впрочем, ситуация чуть сложнее, поскольку явно выраженного и всеми поддерживаемого стандарта работы с зависимостями нет и каждый крутит педали своего собственного маленького самоката - а, значит, есть что обсудить и сравнить.

В данной статье я рассмотрю самые популярные инструменты и подходы для организации иерархии зависимостей в go, с их преимуществами и недостатками. В случае, если вы знаете теорию и аббревиатура DI не вызывает у вас вопросов (в том числе и необходимость применения этого подхода), то можете начинать читать статью с середины, в первую половине я объясню, что такое DI, зачем это нужно вообще и в частности в го.

### Зачем нам всё это нужно
Стоит начать с того, что главный враг всех программистов и главная причина появления практически всех инструментов проектирования - это сложность. Тривиальный случай всегда понятен, легко ложится в голову, очевидно и изящно решается одной строчкой кода и с ним никогда не бывает проблем. Иное дело, когда в системе десятки и сотни тысяч (а иногда и больше) строк кода, и великое множество “движущихся” частей, которые переплетаются, взаимодействуют, да и просто существуют в одном тесном мирке, где кажется невозможным развернуться, не задев кого-то локтями.
Для решения проблемы сложности человечество пока не нашло пути лучше, чем разбивать сложные вещи на простые, изолируя их и рассматривая по отдельности.
Ключевая вещь здесь - это изоляция, пока один компонент не влияет на соседние, можно не опасаться неожиданных эффектов и неявного воздействия одним на результат работы второго. Для обеспечения такой изоляции мы решаем контролировать связи каждого компонента, явно описав, от чего и как он зависит.
На этом моменте мы приходим к инъекции (или внедрению) зависимостей, которая на самом деле является просто способом организовать код так, чтобы каждому компоненту (класс, структура, модуль, etc.) были доступны только необходимые ему части приложения, скрывая от него всё излишнее для его работы или, цитируя википедию: “DI - это процесс предоставления внешней зависимости программному компоненту”.

Такой подход решает сразу несколько задач:
* Скрывает излишнее, уменьшая когнитивную нагрузку на разработчика;
* Исключает неожиданные побочные эффекты (то есть, неявное влияние одних компонентов на работу других);
* Абстрагирует одни компоненты от других, позволяя легко их заменять, тестировать и изменять;

#### Про жизненный цикл или при чём тут DI
Каждое приложение или его компонент для осуществления своей полезной работы требует решения дополнительных инфраструктурных задач. Эти действия можно объединить в несколько фаз:
* Запуск - приложение или компонент должно запустится и провести приготовления к работе: считать и применить конфигурацию, проверить доступ до внешних систем, от которых зависит непосредственно (например, база данных), начать слушать порт и так далее;
* Работа - наше приложение или компонент осуществляет свою полезную деятельность;
* Завершение работы - приложение или компонент прекращают принимать новые сигналы, заканчивают обрабатывать накопившиеся задачи, останавливают свою деятельность, закрывают соединения и так далее.

Эти три фазы - упрощенно - и есть основной жизненный цикл приложения и упоминаются они вместе с DI по той причине, что жизненный цикл приложения не может не основываться на зависимостях между компонентами приложения. 
Безусловно, управление компонентами и решение вопросов их инициализации (собственно, DI) - это всё же две разные задачи, но они часто решаются одними и теми же инструментами, а также связаны между собой, так что я позволю себе вольность рассматривать их как одно целое в рамках данной статьи.
Тут также следует заметить, что существуют различные подходы как реализации самого DI (внедрение через конструктор, сеттер или свойство), так и реализации системы резолвинга зависимостей (DI-контейнер, сервис локатор, тп), которые тоже обладают своими плюсами и минусами, но это уже вопросы, который необходимо рассматривать отдельно, в какой-нибудь другой статье.

##### Пример:
Представим, что мы пишем простой и типичный сервер, который принимает JSON’ы из сети, кладёт их в базу и обратно.
Это означает, что у нас есть:

* Конфигурация, в которой описано, какой порт слушать и к какой базе присоединяться;
* Сервер, который слушает порт;
* Некий коннектор (соединение или пул соединений) к базе данных;

Захотим ли мы поднять сервер или соединение к бд, если у нас не получилось считать конфигурацию?
Устроит ли нас случай, когда сервер уже поднялся, прежде чем выяснилось, что на самом деле база недоступна и часть запросов уже оказалась получена и упала с закономерными internal server error? (или наоборот, мы успели обратиться в базу, создать соединение и тп, прежде чем обнаружили, что указанный порт недоступен?)
Нравится ли нам такой вариант, что при отключении/перезапуске конкретного сервиса пользователи успевают добежать до него и получить ошибку, потому приложение просто моментально завершило работу (возможно даже и в середине обработки чьего-то запроса)?

Эти проблемы решаются иерархией обработки компонентов приложения: сначала мы считываем конфигурацию, потом инициализируем соединение с бд, только потом поднимаем сервер и так далее.
При получении же заветного SIGINT, вместо моментального падения приложение сначала ждёт окончания обработки всех текущих запросов, потом выключает сервер, потом аккуратно закрывает соединение с базой данных и только потом окончательно завершает свою работу. Такое "аккуратное" безопасное завершение работы компонентов, кстати, называется Graceful shutdown.

Реализуя такое поведение в коде, мы бы, конечно, могли написать прямо в самих компонентах вызовы других компонентов с требованием завершить работу, но это бы нарушило принцип единой ответственности и закономерно превратило бы весь наш код в огромную кучу спагетти, без возможности точно понять что и когда вызовется и как вызов одной функции наложится на вызов другой.
Таким образом, существует две разные задачи, которые мы бы хотели отделить друг от друга и которые можно решить, применяя DI:
* Управление иерархией компонентов приложения, то есть, определить, что от чего зависит, в каком порядке их всех создать и запустить или завершить, чтобы никто из них вдруг не обнаружил, что работает с ещё не созданным или уже завершенным компонентом;
* Работу самих компонентов приложения: они просто работают, вызывая нужные им другие компоненты и не отвечая за вопросы инициализации, прогрева или остановки работы приложения;

### DI не нужен или нужен только в Java
Если ваш код не состоит из одной длинной функции, то он безусловно будет состоять из набора компонентов, почти каждый из которых будет требовать для своей работы каких-то других компонентов. Соответственно, вы всё равно будете решать всё те же задачи управления зависимостями, только более или менее явным способом.
В совсем маленьких сервисах зависимостей, как правило, не очень много и любые вопросы архитектуры являются чем-то вроде порядка на вашем столе: скорее вопросы личной гигиены и чувства прекрасного, чем жизненная необходимость. Но тут нужно учесть пару нюансов: во-первых, наносервисы вполне заслуженно считаются антипаттерном (а, это значит, что у вас в микросервисе всё-таки будет достаточно много кода), во-вторых, программы всегда стремятся к усложнению и никогда к упрощению (что означает, что любой наносервис сейчас всё же имеет хорошие шансы стать больше в будущем), а в третьих существует так называемая "теория разбитых окон", согласно которой бардак, начавшись в маленьких и (казалось бы) неважных частях системы стремится к распространению в другие и морально облегчает заведение бардака в более важных частях приложения.
Поэтому лично я бы сказал, что существует ряд архитектурных практик, которые ничего не стоят, если начать их придерживаться на старте проекта, а их отсутствие вызовет у вас большую боль в будущем, когда очередной сервис немного подрастёт. Например, когда вы захотите написать тесты и замокать пару компонентов, или заменить реализацию одного компонента другим. 

Теперь перейдём к практике.

### Замечание
Данная статья не преследует цель предоставить исчерпывающую документацию по представленным библиотекам и утилитам, поэтому мной были выбраны максимально упрощенные примеры кода, просто чтобы продемонстрировать концептуальную разницу в рассматриваемых подходах. Естественно, все упомянутые инструменты умеют обрабатывать ошибки, возвращаемые конструкторами и обладают множеством дополнительных возможностей, соответствующие примеры можно найти в их документации.
Используемые примеры кода доступны на [https://github.com/vivid-money/article-golang-di](https://github.com/vivid-money/article-golang-di).

### Ещё замечание

Для всех примеров я буду использовать простенькую иерархию, состоящую из трех компонентов, *Logger* - это интерфейс, написанный под логгер из стандартной библиотеки, *DBConn* будет изображать соединение с базой данных, а *HTTPServer*, логично, сервер, слушающий определённый порт и производящий некий (фейковый) запрос к базе данных. Соответственно, инициализироваться и запускаться они должны в порядке *Logger*->*DBConn*->*HTTPServer*, а завершаться в обратном порядке.
Для демонстрации работы с блокирующимися и неблокирубщимися компонентами, DBConn не требует постоянной работы (просто необходимо один раз вызвать `DBConn.Connect()`), а `httpServer.Serve`, напротив, блокирует текущий поток исполнения.

### Reflection based container
Начнём с распространенного в других языках варианта, который в мире го в основном представлен пакетами https://github.com/uber-go/dig и расширяющим его https://github.com/uber-go/fx.
Идея проста, граф зависимостей можно легко динамически описать в рантайме, там же к каждому из компонентов можно привязать хуки на старт и завершение работы. Посмотрим, как это выглядит на простом примере:

```go
{{ quote_go_func_body "./pkg/try_dig/main.go" "main" }}
```

Также fx предоставляет возможность работать непосредственно с жизненным циклом приложения:
```go
{{ quote_go_func_body "./pkg/try_fx/main.go" "main"  }}
```
Может возникнуть вопрос, должен ли метод Serve быть блокирующим (по аналогии с ListenAndServe) или нет? Моя точка зрения на это проста: сделать блокирующий метод неблокирующим очень просто (`go blockingFunc()`), а вот обратное очень сложно. Так как любой код должен в том числе и облегчать работу с собой тем, кто его использует, логичнее всего предоставлять синхронный код, а ассинхронным его пусть сделает вызывающий, если ему это понадобится.

Возвращаясь к fx, в особенно сложных ситуациях можно использовать разнообразные специальные типы (`fx.In`, `fx.Out` и тд) и аннотации (`optional`, `name` и тд), позволяющие компонентам, зависящим от одинаковых интерфейсов, получать различные зависимости или просто связывать что-то по кастомным именам.
Также доступны хелперы, дающие дополнительные возможности, например, `fx.Supply` позволяет добавить в контейнер уже инициализированный объект в случае, если вы по какой-то причине не хотите его инициализировать используя сам контейнер, но хотите использовать его для других компонентов.

Такой "динамический" подход имеет свои плюсы:
* Нет нужды поддерживать порядок, мы просто регистрируем конструкторы, а потом обращаемся к нужным интерфейсам и всё происходит самостоятельно, "волшебным образом". Соответственно, проще добавлять новый код;
* За счёт динамического построения графа зависимостей, легко как подменять какие-то части на моки, так и вовсе тестировать отдельные части приложения;
* Можно запросто использовать любые внешние библиотеки, просто добавив их конструкторы в контейнер;
* Позволяет писать меньше кода;
* Не требует xml или yaml;

Минусы:
* Больше магии, сложнее разбираться с проблемами;
* Поскольку контейнер собирается динамически, в рантайме, то мы теряем compile-time гарантии - узнать о многих проблемах с зависимостями (например, забыли что-то зарегистрировать) можно только запустив приложение, иногда в особой конфигурации. Отчасти надёжность можно было бы повысить тестами, но именно _гарантий_ такой подход всё равно не даст.
* Конкретно для fx:
* * Нет возможностей обрабатывать ошибки работы компонентов (когда Serve внезапно прекращает работу и возвращает ошибку), придётся писать свои велосипеды, благо, это дело не самое сложное;

### Кодогенерация
Остальные способы основываются на статическом коде и первым из них на ум приходит кодогенерация, которая в go представлена преимущественно https://github.com/google/wire за авторством всем известной компании.
Из самого названия этого подхода логично следует, что вместо того, чтобы резолвить зависимости динамически, мы сгенерируем явный статический и типизированный код. Таким образом, в случае ошибки на уровне графа зависимостей он или не сгенерируется, или не скомпилируется, соответственно, мы получаем compile-time гарантии решения зависимостей.
При таком подходе весь вопрос заключается в том, как именно мы будем описывать наш граф зависимостей, чтобы потом сгенерировать для него код. В разных языках для описания связей в коде используются различные средства, от аннотаций до конфигурационных файлов, но, поскольку в мире го аннотаций не существует, а магические комментарии - это вещь очень спорная и обладает известными недостатками, разработчики в итоге остановились на конфигурировании кодом. Выглядит это следующим образом:

В начале необходимо описать компоненты и конструкторы для них, стандартным способом.
Затем в отдельном файле мы регистрируем конструкторы под специальным билд-тегом (чтобы код не попал в компиляцию уже "боевого" приложения и не возникало ошибок, связанных с одинаковыми именами функций):
```go
{{ quote_file "./pkg/try_wire/wireinject.go"  }}
```

В итоге, после вызова одноименной утилиты `wire` (можно делать это через `go generate`), wire просканирует ваш код, найдёт все вызовы wire и сгенерирует файл с кодом, который проводит все инжекты:
```go
{{ quote_go_func "./pkg/try_wire/wire_gen.go" "initializeHTTPServer"  }}
```

Соответственно мы можем сразу же вызывать `initializeHTTPServer` при старте нашего приложения и использовать сгенерированный код, который создаст и "прокинет" куда надо все зависимости:
```go
{{ quote_file "./pkg/try_wire/main.go"  }}
```

Плюсы такого подхода:
* Очень явный и предсказуемый код;
* Гарании на уровне компиляции;
* Всё ещё не нужно ничего собирать руками;
* Конфигурация выглядит достаточно минималистично, мы просто обозначаем интерфейсы и вызываем магическую функцию `wire.Build`;
* Всё ещё никаких xml;
* Wire предоставляет возможность возвращать кроме каждого из компонентов ещё и cleanup-функции, что удобно.

Однако есть и минусы:
* Приходится делать лишние телодвижения, даже описание графа через инжекторы всё-таки занимает место;
* Тяжелее использовать для тестов и моков, из-за отстутствия явных инструментов работы с абстрактными зависимостями; Это конечно решаемо, например, инжектом конструкторов, но всё равно тянет "лишние" сложности;
* Конкретно для wire (нужно учитывать, что он ещё в бете):
* * Не умеет соотносить конструктор, возвращающий конкретный объект с зависимостью от интерфейса, если он этот объект реализует;
* * Нет нормальной поддержки жизненного цикла, это заставляет писать свои конструкторы, которые ещё и запускают/останавливают его, что неудобно и в общем смысле, и для использования конструкторов из внешних библиотек;
* * По той же причине приходится изобретать свой велосипед для остановки приложения в случае "падения" одного из компонентов;
* * Cleanup'функции вызываются просто по порядку, если в процессе одной из них произойдёт паника, то остальные не вызовутся.

### Собираем граф руками
Для пришедших из других языков это могло бы звучать дико, но на самом деле вам не нужны серьёзные и сложные инструменты для того, чтобы управлять небольшим (или большим, но стабильным) графом зависимостей. Если это вызывает проблемы, то, конечно, лучше взять wire или dig/fx, но я могу вас уверить, что проблем с таким подходом у вас будет значительно меньше, чем вам кажется (или не будет вообще).
Одной из причин этому будет отсутствие у гошников манеры создавать избыточное количество компонентов (вместо отдельных классов-фабрик или даже фабрик-для-фабрик обычно создаётся простая функция-конструктор), другой - некоторые специфические возможности го.

Так вот, давайте представим простой код, который сделает все необходимые инжекты:
```go
{{ quote_go_func_body "./pkg/try_manual_pure/simple_example.go" "simpleExampleA" }}
```

Это будет работать, это вполне минималистично, насколько это вообще можно без рантаймовой магии в данном языке, и вам не будет особенно дорого по необходимости (добавился новый аргумент или вообще новый компонент) добавить пару строк в этот код.
Вся сложность здесь будет в том, как реализовать жизненный цикл, потому что вариантов существует несколько.
Первым рассмотрим способ, про который Avito рассказывали вот в [этом](https://www.youtube.com/watch?v=me5iyiheOC8) докладе:
#### Используем errgroup.
Выглядит оно вот так:
```go
{{ quote_go_func "./pkg/try_manual_errgroup/main.go" "main" }}
```
Как это работает?
Мы запускаем все компоненты нашего приложения в отдельных горутинах, но при этом запускаем не вручную, а через специальную структуру g, которая:
1. Будет считать запущенные через неё функции (чтобы потом дождаться всех);
2. Предоставляет собственный контекст с возможностью отмены (получаем иерархию `ctx.cancel`->`gCtx.cancel` для каждой конечной функции);
3. Будет внимательно смотреть на результаты функций, если хоть одна из них завершится ошибкой - то отменит свой контекст, в результате чего все функции смогут получить сигнал отмены через переданные им gCtx и завершить свою работу.

Такая схема в целом неплоха, но я нахожу в ней определённый фатальный недостаток: errgroup заставляет положиться на событие отмены контекста. Такой подход не гарантирует порядка отмены каждой из функций, каждая из них может проверить переданный ей gCtx на `.Done()` в любой удобный для неё момент и в итоге мы теоретически можем получить ситуацию, когда у вас соединение с базой получило `cancel` и завершилось до того, как какой-то более высокоуровневый компонент (например, обрабатывающий важный сетевой запрос) завершил свою работу.
Кроме того:
* errgroup возвращает только первую ошибку, остальные игнорирует;
* errgroup отменяет контекст только в том случае, если какой-то из компонентов вернул ошибку. Если же по какой-то причине некий компонент завершится без ошибки, то система не отреагирует, продолжив работать, как ни в чём не бывало. Да, это можно исправить каким-нибудь велосипедом, но в таком случае зачем мы вообще что-то брали, если потом всё равно придётся дописывать?

#### Следующий способ - это самописный lifecycle.
Идея, кажется, лежит на поверхности: если errgroup не даёт нам нужных гарантий, можно написать свой велосипед, который их даёт.
Таких идей в своё время не избежал и я и лично у меня получилось что-то такое:
```go
{{ quote_go_func_body "./pkg/try_selfwritten_lifecycle/main.go" "main" }}
```
И такая идея хороша всем, кроме того, что делает сложным образом то, что можно сделать намного проще, используя нативные средства самого языка.
(именно поэтому реализации моего пакета `lifecycle` я не стал нигде выкладывать, это не имеет смысла)

#### Способ финальный
Существуй мы в мире Java или где-то ещё, то остановились бы на предыдущем варианте, поскольку отслеживать порядок инициализации, запуска и остановки сервисов "руками" звучит, как очень неблагодарная работа без права на ошибку.
Но в го есть три удобных инструмента, которые значительно облегчают это дело.
Про горутины в курсе, вероятно, все, кто хоть чуть-чуть этим интересовался, и если вы не в их числе, то вряд ли вы поняли предыдущие примеры кода, так что я не стану добавлять пояснения, тем более, что это вопрос буквально одного абзаца из первой же ссылки в гугле.
Второй такой удобный инструмент, это контекст, некий "волшебный" интерфейс, который принимает, наверное, уже почти любая функция в го и который кроме всего прочего предоставляет функциям возможность узнать, был ли данный контекст отменён (или отменить его самостоятельно для нижележащих функций). В результате такой механизм даёт нам контроль, позволяя каскадно завершать работу функции или группы функций - в том числе и из main-функции.
Третий удобный и чуть менее очевидный инструмет, defer, является просто ключевым словом, добавляющим в некий стек текушей функции другую функцию, которая должна быть выполнена после завершения текущей.
А это означает, что во-первых, после defer'а можно делать сколько угодно return'ов не боясь, что где-то забудешь разблокировать мьютекс или закрыть файл (кстати, очень способствует сокращению ветвлений в коде), а во-вторых, _они вызываются в обратном порядке_. Можно вызывать конструкторы и каждый раз при вызове регистрировать деструктор и они вызовутся сами, по очереди, в правильном порядке с точки зрения графа зависимостей, не требуя никаких дополнительных инструментов:
```go
{{ quote_go_func_body "./pkg/try_manual_pure/simple_example.go" "simpleExampleB" }}
```

Правда, остаётся ещё вопрос обработки ошибок, а также возврата первоначальной ошибки (что необязательно, но мне нравится делать именно так). Дело не обойдётся без трех маленьких хелперов:
* ErrSet - хранилище ошибок для их использования на уровне старта/остановки приложения;
* Serve - получает контекст и функцию-server, стартует этот server в отдельной горутине и при этом возвращает новый контекст, обернутый в WithCancel, вызываемый при завершении функции-server'а (что позволяет прекратить запуск приложения на середине, если один из предыдущих server'ов завершился);
* Shutdown - просто вызывает функцию и пишет возможную ошибку в ErrSet, потому что когда приложение уже завершается, нет необходимости как-либо отдельно обрабатывать ошибки завершения компонентов;

В итоге, код будет выглядеть так:
```go
{{ quote_file "./pkg/try_manual_pure/main.go" }}
```
В качесте примечания укажу, что в данном примере все компоненты запускаются исключительно в фоновом контексте и напомню, что это лишь демонстрационный образец, который не включает в себя обработку части ошибок и прочих необходимых в продакшене вещей.

Что нам даёт такой подход?
* Добавление компонентов происходит как и раньше, копипастом магических четырех слов New-Serve-defer-Shutdown (будь у нас дженерики, кстати, можно было бы ещё набросать простенький хелпер, чтобы было ещё меньше кода и совсем симпатично);
* Поскольку при таком подходе вы можете инициализировать компоненты только в том порядке, в каком они зависят друг от друга, то ошибка, при которой вы начнёте или завершите работу компонентов в неправильном порядке сведена к нулю;
* Ошибка в середине инициализации сервиса приводит к досрочному завершению приложения;
* Завершение работы компонентов происходит в правильной (с точки зрения порядка зависимостей) последовательности;
* Ошибка работы случайного компонента приведет к завершению приложения, но последовательность завершения всё равно останется правильной, от конца к началу;
* Мы 100% дождёмся окончания всех компонентов, прежде, чем завершить приложение;
* Весь код, осуществляющий работу жизненного цикла, описан очень явно и не содержит никакий магии;

Недостатки
* Пишется руками, а значит при сотнях зависимостей может потребоваться переходить к кодогенерации;

### Выводы
Самой лучшей практикой всегда остаётся выбор подходящего инструмента под определённую задачу.
Все рассмотренные мной решения имеют свои достоинства и недостатки, как сами по себе, так и применительно к специфике разработки на golang.
Описанный первым fx несмотря на свою некоторую неидиоматичность (в контексте go), выглядит хорошо проработанными и решает практически все необходимые задачи, а что не решает - несложно дописать руками.
Wire несмотря на громкое имя создателей выглядит сыроватым и несколько недоработанным, но при этом безусловно идиоматичен и в состоянии продемонстрировать преимущества кодогенерации.
При этом инжекты руками не выглядят (да и не являются, по моему опыту) особенно болезненными, а все необходимые задачи можно решить с помощью стандартных `go`, `context`, `defer` и пары хелперов минимального размера.
Важнейшим делом всегда является архитектура, правильное моделирование предметной области и правильное разделение логики приложения на части с правильными зонами ответственности, а вопрос автоматизации инжектов зависимостей не является критичным, до определённого размера или определённой сложности. Лично я бы до действительно сотен компонентов без проблем использовал подход сбора графа зависимостей руками, а уже потом присмотрелся к wire (может, к тому времени он научиться решать вообще все задачи, решения которых хотелось бы от него ожидать).

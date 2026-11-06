# Arquitectura de FreshMarket

Este documento muestra **cada clase en su capa**, cómo se conectan, el
modelo de datos SQL y cómo se recorre el ciclo completo de una acción.
Los diagramas están en Mermaid: GitHub y VS Code los dibujan solos.

## 1. Capas

```mermaid
flowchart TB
    subgraph UI["Capa de presentación (lib/ui)"]
        V["Vistas (Screens y widgets)<br/>dibujan y reciben toques"]
        VM["ViewModels (ChangeNotifier)<br/>estado + comandos"]
    end
    subgraph DATA["Capa de datos (lib/data)"]
        R["Repositorios<br/>JSON → modelo, caché, reintentos, esperas"]
        S["Servicios (interfaces + implementaciones)<br/>red, GPS, cámara, disco; sin estado"]
    end
    subgraph DOM["Dominio (lib/domain/models)"]
        M["Modelos puros e inmutables<br/>Producto, Pedido, Posicion..."]
    end
    CFG["config/dependencias.dart<br/>arma todo (inyección de dependencias)"]
    BE[("Backend Node + SQLite<br/>backend/")]

    V -- "llama comandos" --> VM
    VM -- "notifyListeners() (Observer)" --> V
    VM --> R
    R --> S
    S -- "HTTP" --> BE
    V -.usa.-> M
    VM -.usa.-> M
    R -.crea.-> M
    CFG -.construye.-> R
    CFG -.construye.-> S
```

Reglas que se cumplen en todo el proyecto (y que se pueden verificar con
`grep`):

| Regla | Cómo se verifica |
|---|---|
| Ninguna vista habla con la red | `grep -rn "ApiClient\|http\." lib/ui` no devuelve nada |
| Ningún ViewModel importa `material.dart` ni recibe `BuildContext` | `grep -rln "material.dart" lib/ui/*/view_models` no devuelve nada |
| Ningún ViewModel importa la capa de servicios | `grep -rn "data/services" lib/ui/*/view_models` no devuelve nada |
| Los servicios no guardan estado de la app | Solo los simulados, que hacen de "servidor" (está comentado en cada uno) |
| Los repositorios no dependen entre sí | Cada uno recibe solo servicios en su constructor |
| Encapsulamiento: estado privado, getters públicos, listas inmutables hacia afuera | Todos los campos que cambian empiezan con `_`; `items` devuelve `List.unmodifiable` |

## 2. Diagrama de clases

Para que se lea, cada interfaz de servicio aparece con sus
implementaciones (real y simulada) y cada pantalla con su ViewModel.

```mermaid
classDiagram
    direction LR

    %% ---------- Vistas ----------
    class InicioScreen
    class CatalogoScreen
    class CarritoScreen
    class PagoScreen
    class ElegirUbicacionScreen
    class SeguimientoScreen
    class IngresarScreen
    class RecuperarClaveScreen
    class AlmacenScreen
    class EscanerScreen
    class RepartoScreen
    class CampoClave

    %% ---------- ViewModels ----------
    class NavegacionViewModel {
      -Seccion _actual
      +irA(Seccion)
    }
    class CatalogoViewModel {
      -List~Producto~ _productos
      +cargar()
      +buscar(String)
      +elegirCategoria(String)
    }
    class CarritoViewModel {
      -List~ItemCarrito~ _items
      +agregarProducto(Producto)
      +quitarProducto(Producto)
      +armarPedido(MetodoPago) Pedido
      +guardar()
      +restaurar()
    }
    class PagoViewModel {
      -MetodoPago _metodo
      -String _direccion
      -Posicion _destino
      +marcarDestino(Posicion, direccion)
      +pagar()
    }
    class ElegirUbicacionViewModel {
      -Posicion _punto
      -String _direccion
      +marcar(Posicion)
      +usarMiUbicacion()
      +resultado UbicacionEntrega
    }
    class SeguimientoViewModel {
      +seguir(Pedido)
    }
    class SesionViewModel {
      -Sesion _sesion
      +ingresar(email, clave)
      +salir()
    }
    class RecuperarClaveViewModel {
      +enviarCodigo(email)
      +cambiarClave(codigo, claveNueva, repetida)
    }
    class AlmacenViewModel
    class EscanerViewModel
    class RepartoViewModel

    %% ---------- Repositorios ----------
    class CatalogoRepository {
      -List~Producto~ _cache
    }
    class CarritoRepository
    class PagoRepository
    class UbicacionEntregaRepository {
      -Map _cache
      +direccionDe(Posicion) String
      +miPosicion() Posicion
    }
    class SeguimientoRepository
    class SesionRepository
    class EtiquetadoRepository
    class RepartoRepository

    %% ---------- Servicios (interfaces) ----------
    class CatalogoService {<<interface>>}
    class CarritoLocalService {<<interface>>}
    class PagoService {<<interface>>}
    class CheckoutLauncher {<<interface>>}
    class GeocodificacionService {<<interface>>}
    class UbicacionService {<<interface>>}
    class SeguimientoService {<<interface>>}
    class SesionService {<<interface>>}
    class EtiquetadoService {<<interface>>}
    class CamaraService {<<interface>>}
    class RepartoService {<<interface>>}
    class ApiClient {
      -String _token
      +usarToken(String)
      +get() post() put() delete()
    }

    %% Vistas -> ViewModels
    InicioScreen --> NavegacionViewModel
    CatalogoScreen --> CatalogoViewModel
    CatalogoScreen --> CarritoViewModel
    CarritoScreen --> CarritoViewModel
    PagoScreen --> PagoViewModel
    PagoScreen ..> ElegirUbicacionScreen : abre
    ElegirUbicacionScreen --> ElegirUbicacionViewModel
    SeguimientoScreen --> SeguimientoViewModel
    IngresarScreen --> SesionViewModel
    IngresarScreen ..> RecuperarClaveScreen : abre
    IngresarScreen *-- CampoClave
    RecuperarClaveScreen --> RecuperarClaveViewModel
    RecuperarClaveScreen *-- CampoClave
    AlmacenScreen --> AlmacenViewModel
    EscanerScreen --> EscanerViewModel
    RepartoScreen --> RepartoViewModel

    %% ViewModels -> Repositorios
    CatalogoViewModel --> CatalogoRepository
    AlmacenViewModel --> CatalogoRepository
    CarritoViewModel --> CarritoRepository
    PagoViewModel --> PagoRepository
    ElegirUbicacionViewModel --> UbicacionEntregaRepository
    SeguimientoViewModel --> SeguimientoRepository
    SesionViewModel --> SesionRepository
    RecuperarClaveViewModel --> SesionRepository
    EscanerViewModel --> EtiquetadoRepository
    EscanerViewModel --> CatalogoRepository
    RepartoViewModel --> RepartoRepository

    %% Repositorios -> Servicios
    CatalogoRepository --> CatalogoService
    CarritoRepository --> CarritoLocalService
    PagoRepository --> PagoService
    PagoRepository --> CheckoutLauncher
    UbicacionEntregaRepository --> GeocodificacionService
    UbicacionEntregaRepository --> UbicacionService
    SeguimientoRepository --> SeguimientoService
    SesionRepository --> SesionService
    EtiquetadoRepository --> EtiquetadoService
    EtiquetadoRepository --> CamaraService
    RepartoRepository --> RepartoService
    RepartoRepository --> UbicacionService

    %% Implementaciones (Strategy: real o simulada)
    CatalogoService <|.. CatalogoServiceHttp
    CatalogoService <|.. CatalogoServiceLocal
    CarritoLocalService <|.. CarritoLocalServicePreferencias
    CarritoLocalService <|.. CarritoLocalServiceMemoria
    PagoService <|.. PagoServiceHttp
    PagoService <|.. PagoServiceSimulado
    CheckoutLauncher <|.. CheckoutLauncherExterno
    CheckoutLauncher <|.. CheckoutLauncherSimulado
    GeocodificacionService <|.. GeocodificacionServiceHttp
    GeocodificacionService <|.. GeocodificacionServiceSimulado
    UbicacionService <|.. UbicacionServiceGeolocator
    SeguimientoService <|.. SeguimientoServiceHttp
    SeguimientoService <|.. SeguimientoServiceSimulado
    SesionService <|.. SesionServiceHttp
    SesionService <|.. SesionServiceSimulado
    EtiquetadoService <|.. EtiquetadoServiceHttp
    EtiquetadoService <|.. EtiquetadoServiceSimulado
    CamaraService <|.. CamaraServiceImagePicker
    RepartoService <|.. RepartoServiceHttp
    RepartoService <|.. RepartoServiceSimulado

    CatalogoServiceHttp --> ApiClient
    PagoServiceHttp --> ApiClient
    GeocodificacionServiceHttp --> ApiClient
    SeguimientoServiceHttp --> ApiClient
    SesionServiceHttp --> ApiClient
    EtiquetadoServiceHttp --> ApiClient
    RepartoServiceHttp --> ApiClient
```

### Modelos de dominio

```mermaid
classDiagram
    direction LR
    class Producto {
      +String id
      +String nombre
      +double precio
      +String categoria
      +bool disponible
      +fromJson() toJson()
    }
    class ItemCarrito {
      +Producto producto
      +int cantidad
      +subtotal double
      +copiarCon(cantidad)
    }
    class Pedido {
      +String id
      +int numero
      +List~ItemCarrito~ items
      +MetodoPago metodoPago
      +String direccion
      +Posicion destino
      +total double
    }
    class Posicion {
      +double latitud
      +double longitud
    }
    class UbicacionEntrega {
      +Posicion posicion
      +String direccion
    }
    class SeguimientoPedido {
      +EstadoPedido estado
      +Posicion posicionRepartidor
    }
    class Sesion {
      +Rol rol
      +String token
      +String nombre
    }
    class MetodoPago {<<enum>> debito credito billeteraMercadoPago efectivo}
    class EstadoPedido {<<enum>> recibido enPreparacion enCamino entregado}
    class Rol {<<enum>> dueno repartidor}

    Pedido "1" *-- "1..*" ItemCarrito
    ItemCarrito --> Producto
    Pedido --> MetodoPago
    Pedido --> Posicion
    UbicacionEntrega --> Posicion
    SeguimientoPedido --> EstadoPedido
    SeguimientoPedido --> Posicion
    Sesion --> Rol
```

## 3. Ciclo completo: tocar el mapa y que aparezca la dirección

```mermaid
sequenceDiagram
    actor Cliente
    participant V as ElegirUbicacionScreen
    participant VM as ElegirUbicacionViewModel
    participant R as UbicacionEntregaRepository
    participant S as GeocodificacionServiceHttp
    participant B as Backend /geo/inversa
    participant N as Nominatim (OpenStreetMap)

    Cliente->>V: toca el mapa
    V->>VM: marcar(Posicion)
    VM-->>V: notifyListeners() → "Buscando la dirección..."
    VM->>R: direccionDe(Posicion)
    alt ya consultada
        R-->>VM: dirección de la caché
    else nueva
        R->>S: direccionDe(lat, lng)
        S->>B: GET /geo/inversa?lat&lng
        B->>B: busca en direcciones_cache (SQL)
        B->>N: reverse (si no estaba)
        N-->>B: calle y número
        B-->>S: { direccion }
        S-->>R: JSON
        R-->>VM: "San Martín 1234, Mendoza"
    end
    VM-->>V: notifyListeners() → muestra la dirección
    Cliente->>V: "Es acá"
    V-->>Cliente: vuelve al pago con el cuadro de texto ya completo
```

## 4. MVC y MVVM

La materia usa **MVVM**, que es la forma en que Flutter recomienda aplicar
la idea de **MVC** (Modelo–Vista–Controlador). Se corresponden así:

| MVC | En FreshMarket (MVVM) | Qué hace |
|---|---|---|
| **Modelo** | `domain/models` + `data/repositories` + `data/services` | Los datos y las reglas para obtenerlos y guardarlos |
| **Vista** | `ui/*/widgets` (Screens) | Dibuja el estado y avisa los toques |
| **Controlador** | `ui/*/view_models` (ViewModels) | Recibe las acciones, cambia el estado y avisa a la vista |

La diferencia es **cómo se entera la vista**: en MVC clásico el
controlador le dice a la vista qué cambiar; en MVVM la vista **observa** al
ViewModel (`ListenableBuilder` + `notifyListeners()`, patrón Observer) y se
redibuja sola. Así el ViewModel no conoce ningún widget y se puede probar
sin pantalla (por eso hay pruebas de cada ViewModel con fakes).

## 5. Modelo de datos (SQL)

El esquema completo está en [`backend/sql/schema.sql`](../backend/sql/schema.sql)
y los datos iniciales en [`backend/sql/seed.sql`](../backend/sql/seed.sql).
Se crea con `cd backend && npm run bd:crear`.

```mermaid
erDiagram
    productos {
      TEXT id PK
      TEXT nombre "1 a 80 caracteres"
      INTEGER precio "mayor a 0"
      TEXT categoria "lista cerrada"
      TEXT emoji
      TEXT descripcion
      INTEGER disponible "0 o 1"
    }
    pedidos {
      INTEGER numero PK "AUTOINCREMENT desde 1001"
      TEXT id UK
      TEXT metodo_pago "debito, credito, billetera, efectivo"
      TEXT items "JSON: foto del pedido"
      INTEGER total "mayor a 0"
      TEXT direccion
      REAL destino_lat
      REAL destino_lng
      TEXT estado_pago "pendiente, aprobado, rechazado"
      INTEGER aprobado_en
      INTEGER entregado "0 o 1"
    }
    posiciones {
      TEXT pedido_id PK,FK
      REAL lat
      REAL lng
      TEXT nombre
      INTEGER en
    }
    usuarios {
      INTEGER id PK
      TEXT email UK "sin distinguir mayúsculas"
      TEXT nombre
      TEXT rol "dueno o repartidor"
      TEXT clave_hash "scrypt"
      TEXT clave_sal
      INTEGER creado_en
    }
    recuperaciones_clave {
      INTEGER id PK
      INTEGER usuario_id FK
      TEXT codigo_hash "HMAC del código"
      INTEGER vence_en "15 minutos"
      INTEGER intentos "máximo 5"
      INTEGER usado "0 o 1"
      INTEGER creado_en
    }
    direcciones_cache {
      TEXT clave PK "lat,lng con 5 decimales"
      TEXT direccion
      INTEGER creado_en
    }

    pedidos ||--o| posiciones : "tiene la última posición de"
    usuarios ||--o{ recuperaciones_clave : "pide"
```

`productos` y `pedidos` no tienen clave foránea a propósito: el pedido
guarda una **foto** de los productos (nombre, precio y cantidad) en
`items`, para que si Don Ceferino cambia un precio o borra un producto,
los pedidos ya hechos no cambien.

# Servintel Operarios

Aplicación móvil multiplataforma desarrollada con Flutter y Firebase como componente del ecosistema Servintel, una solución tecnológica para la gestión y seguimiento de servicios técnicos.

La aplicación está orientada a la interacción entre clientes y operarios, permitiendo gestionar solicitudes de servicio, consultar trabajos, registrar intervenciones técnicas y mantener la trazabilidad del proceso de atención.

## Descripción

Servintel Operarios forma parte de un sistema compuesto por una aplicación móvil y una plataforma web administrativa conectadas al mismo backend.

La aplicación móvil contempla diferentes perfiles de usuario y organiza sus funcionalidades por módulos, incluyendo autenticación, gestión de clientes, gestión de operarios, trabajos técnicos, reportes, geolocalización y evaluación del servicio.

## Funcionalidades principales

### Autenticación y roles

- Inicio de sesión mediante Firebase Authentication.
- Gestión de usuarios mediante Cloud Firestore.
- Enrutamiento de la aplicación según el rol del usuario.
- Manejo de perfiles de cliente y operario.
- Control de acceso mediante reglas de seguridad de Firestore.

### Gestión de clientes

- Consulta de información del cliente.
- Gestión de equipos asociados al cliente.
- Selección de una o varias máquinas para solicitar servicio.
- Registro de la descripción del problema para cada equipo.
- Consulta del historial de trabajos.
- Solicitud de servicios técnicos.
- Selección de ubicación mediante mapa.
- Registro de coordenadas geográficas.
- Aprobación o rechazo del reporte técnico.
- Calificación del servicio recibido.

### Gestión de operarios

- Consulta de trabajos activos y trabajos completados recientemente.
- Búsqueda de trabajos por nombre del cliente.
- Visualización de información del servicio.
- Actualización del estado del trabajo.
- Registro de tiempos asociados al proceso de atención.
- Acceso al reporte técnico.
- Gestión de la información relacionada con la intervención.

### Reportes técnicos

El módulo de reportes permite registrar diferentes tipos de intervención:

- Mantenimiento.
- Venta.
- Alquiler.

Para los trabajos de mantenimiento se pueden registrar, entre otros datos:

- Marca.
- Modelo.
- Identificador del equipo.
- Número de serie.
- Contador.
- Diagnóstico.
- Solución aplicada.
- Insumos utilizados.

Para ventas se contempla información como:

- Descripción.
- Valor.
- Garantía.

Para alquiler se contempla:

- Condiciones.
- Duración.
- Valor mensual.

El formulario permite además manejar múltiples intervenciones dentro de un mismo reporte.

### Geolocalización y mapas

- Obtención de la ubicación actual del dispositivo.
- Solicitud y gestión de permisos de ubicación.
- Selección de una ubicación directamente sobre el mapa.
- Registro de coordenadas de latitud y longitud.
- Visualización de mapas mediante Flutter Map.
- Gestión de ubicaciones asociadas a las solicitudes de servicio.

## Arquitectura del proyecto

El código está organizado por funcionalidades dentro de `lib/features`, separando los módulos de autenticación, cliente y operario.

```text
lib/
├── core/
│   └── constants.dart
│
├── features/
│   ├── auth/
│   │   ├── auth_gate.dart
│   │   ├── login_screen.dart
│   │   └── role_router.dart
│   │
│   ├── cliente/
│   │   ├── cliente_screen.dart
│   │   ├── mapa_cliente_screen.dart
│   │   ├── calificacion_screen.dart
│   │   └── visto_bueno_screen.dart
│   │
│   └── operario/
│       ├── operario_screen.dart
│       ├── reporte_tecnico_screen.dart
│       ├── trabajo_model.dart
│       └── trabajos_repository.dart
│
└── shared/
    └── widgets/
        ├── common_widgets.dart
        └── premium_widgets.dart

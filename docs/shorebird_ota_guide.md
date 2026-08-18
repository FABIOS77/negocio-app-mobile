# 📖 GUÍA OPERATIVA DE SHOREBIRD OTA (CODE PUSH)
**Proyecto:** Katering Grecia App (Flutter Mobile)  
**Módulo:** Infraestructura, Despliegue y Actualizaciones Over-The-Air (OTA)  
**Versión:** 1.0.0

---

## 1. 🌟 Introducción y Arquitectura

**Shorebird** permite desplegar parches de código Dart en tiempo real directamente a los dispositivos de los usuarios sin necesidad de compilar un nuevo archivo APK ni pasar por procesos manuales de reinstalación.

```
┌─────────────────────────┐          ┌──────────────────────────┐          ┌─────────────────────────┐
│   Desarrollador         │          │   Shorebird Cloud        │          │   Dispositivo Cliente   │
│   (Corrige bug en Dart) │          │   (Servidor de Parches)  │          │   (Katering Grecia App) │
└───────────┬─────────────┘          └────────────┬─────────────┘          └───────────┬─────────────┘
            │                                     │                                    │
            │  shorebird patch android            │                                    │
            │ ───────────────────────────────────►│                                    │
            │                                     │  Descarga silenciosa en background │
            │                                     │ ──────────────────────────────────►│
            │                                     │                                    │
            │                                     │  Aplica parche en próximo inicio   │
            │                                     │  (SQLite y JWT 100% intactos)      │
```

---

## 2. ⚙️ Requisitos Previos e Instalación

### A. Instalar la CLI de Shorebird (Windows PowerShell)
Ejecuta en tu terminal de PowerShell como usuario estándar:
```powershell
powershell -c "irm https://raw.githubusercontent.com/shorebirdtech/install/main/install.ps1 | iex"
```

### B. Verificar la Instalación
```bash
shorebird doctor
```
*Asegúrate de que no haya errores críticos en la salida de `doctor`.*

---

## 3. 🚀 Paso 1: Autenticación y Vinculación Inicial del Proyecto

> [!NOTE]
> Este paso se realiza **una sola vez** por el administrador del proyecto.

1. **Iniciar Sesión en Shorebird:**
   ```bash
   shorebird login
   ```
   *Se abrirá el navegador para autenticarte con tu cuenta de Google/GitHub.*

2. **Inicializar Shorebird en la app:**
   Asegúrate de estar en la raíz de `katering grecia app flutter`:
   ```bash
   cd "katering grecia app flutter"
   shorebird init
   ```
   * Shorebird detectará el proyecto Flutter.
   * Asignará un nombre de aplicación (ej. `katering-grecia-app`).
   * Creará automáticamente el archivo `shorebird.yaml` con el `app_id`.
   * **IMPORTANTE:** El archivo `shorebird.yaml` debe comitearse en Git (está configurado en `.gitignore`).

---

## 4. 📦 Paso 2: Generación del Release Base de Producción

> [!IMPORTANT]
> Los parches OTA **solo funcionan sobre aplicaciones instaladas a partir de un Release de Shorebird**. No funcionan sobre builds generados con `flutter build apk` estándar.

Para compilar el APK base que se entregará a los clientes / usuarios:

```bash
shorebird release android --artifact=apk
```

### ¿Qué hace este comando?
1. Compila el APK con el motor de ejecución modificado de Shorebird (`libflutter.so`).
2. Registra la versión base (ej. `1.0.0+1`) en la consola de Shorebird Cloud.
3. Genera el APK en: `build/app/outputs/flutter-apk/app-release.apk`.
4. **Entrega o instala este APK en los dispositivos.**

---

## 5. ⚡ Paso 3: Envío de Parches OTA en Tiempo Real

Cuando realices correcciones de errores, mejoras de interfaz o ajustes en la lógica de negocio en la carpeta `lib/`:

### Procedimiento:
1. Realiza los cambios necesarios en el código Dart.
2. Verifica que el código no tenga errores:
   ```bash
   flutter analyze
   flutter test
   ```
3. **Publica el parche OTA:**
   ```bash
   shorebird patch android
   ```
4. Confirma la versión de destino cuando Shorebird te lo solicite en la terminal.

### ¿Qué experimenta el usuario?
* La app continúa funcionando con normalidad.
* En segundo plano, Shorebird descarga el delta de código compilado (~200 KB - 1 MB).
* La próxima vez que el usuario abra la app, **los cambios estarán aplicados automáticamente**.
* **Persistencia Garantizada:** La base de datos SQLite (`katering_grecia.sqlite`) y las credenciales seguras de `flutter_secure_storage` no se tocan ni se reinician.

---

## 6. ⚖️ Matriz de Restricciones: ¿Qué es Parcheable vs Nuevo Release?

| Componente Modificado | ¿Se puede enviar por Parche OTA (`shorebird patch`)? | ¿Requiere Nuevo Release (`shorebird release`)? |
| :--- | :---: | :---: |
| **Lógica de Sincronización** (`SyncEngine`, `SyncQueueManager`, endpoints) | ✅ **SÍ** | NO |
| **Lógica de Repositorios y Negocio** (`OrdersRepository`, `ExpensesRepository`, cálculos) | ✅ **SÍ** | NO |
| **Interfaz de Usuario / UI** (Widgets, pantallas, colores, estilos, modales) | ✅ **SÍ** | NO |
| **Gestión de Estado** (Riverpod providers, notifiers, listeners) | ✅ **SÍ** | NO |
| **Navegación y Rutas** (`GoRouter`, nuevas pantallas en `lib/`) | ✅ **SÍ** | NO |
| **Consultas SQL en Drift** (Nuevos filtros `WHERE`, subqueries, ordenamiento) | ✅ **SÍ** | NO |
| **Permisos en `AndroidManifest.xml`** | ❌ **NO** | ✅ **SÍ** |
| **Iconos de la App o Splash Screen Nativa** (`flutter_launcher_icons`, `flutter_native_splash`) | ❌ **NO** | ✅ **SÍ** |
| **Configuración Gradle** (`build.gradle.kts`, `minSdk`, `targetSdk`) | ❌ **NO** | ✅ **SÍ** |
| **Nuevos Plugins con Código Nativo** (Kotlin, Swift, bibliotecas C++) | ❌ **NO** | ✅ **SÍ** |

---

## 7. 🛠️ Monitoreo, Diagnóstico y Comandos Frecuentes

* **Ver el estado de salud de Shorebird:**
  ```bash
  shorebird doctor
  ```
* **Listar los releases registrados:**
  ```bash
  shorebird releases list
  ```
* **Consola Web de Administración:**  
  Accede a [console.shorebird.dev](https://console.shorebird.dev) para ver instalaciones activas, descargas de parches y métricas en tiempo real.

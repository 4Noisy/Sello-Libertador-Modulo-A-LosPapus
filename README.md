# Sello Libertador — Paquete de arranque

Proyecto conjunto de los BLOQUES. Todo se trabaja en **Remix IDE**
https://app.remix.live  con el entorno **Remix VM**.

## 1. Idea en una línea

El titulado **no necesita billetera**. Recibe un enlace (o un código QR) como este:

```
https://verifica.ubo.cl/sello?sca=<contrato>&loc=U0ZSA8QPFN&tc=<hash de la tx>&ed=<documento cifrado>#k=<clave>
```

| Parámetro | Qué es | Dónde vive |
|---|---|---|
| `sca` | Dirección del contrato `RegistroTitulos` | Pública; debe coincidir con la dirección OFICIAL de la UBO |
| `loc` | Localizador del título: 10 caracteres `[0-9A-Z]` | En la cadena (clave del registro) |
| `tc` | Hash de la transacción de emisión | En la cadena |
| `ed` | Credencial + sal, cifradas con AES-256-GCM | Solo en el enlace |
| `k` | Clave de descifrado | En el **fragmento** (`#`): el navegador no la envía al servidor |

**Importante:** Remix VM es una cadena simulada dentro del navegador. No existe un portal
web público: el enlace es un formato de datos y el «portal» es el script `verificarEnlace`,
que se ejecuta dentro de Remix y hace los mismos pasos que haría un portal real.

En la cadena solo hay: localizador, compromiso `keccak256(abi.encode(sal, hashDocumento))`,
emisor, facultad, programa, fecha y estado. **Ningún dato personal.**

## 2. Estructura

```
SelloLibertador/
├── contracts/
│   ├── interfaces/     ← NO MODIFICAR (contrato común entre los tres cursos)
│   │   ├── IMultifirmaUBO.sol, IRegistroEmisores.sol   (Módulo A)
│   │   ├── IRegistroTitulos.sol                        (Módulo B)
│   │   └── IVerificadorUBO.sol, IAnclajeLotes.sol,
│   │       IHerramientasSello.sol                      (Módulo C)
│   ├── comun/          ← NO MODIFICAR
│   │   ├── ConstantesUBO.sol   facultades, motivos, MAX_LOTE, compromiso, hoja de Merkle
│   │   └── ActorPruebas.sol    simula varias personas en las pruebas de Remix
│   ├── simulacros/     ← NO MODIFICAR (sustitutos de los módulos de otros cursos)
│   │   ├── SimMultifirmaUBO.sol, SimRegistroEmisores.sol, SimRegistroTitulos.sol
│   ├── moduloA/        ← CURSO A: MultifirmaUBO.sol, RegistroEmisores.sol
│   ├── moduloB/        ← CURSO B: RegistroTitulos.sol
│   └── moduloC/        ← CURSO C: VerificadorUBO.sol, AnclajeLotes.sol, HerramientasSello.sol
├── tests/              ← cada curso completa SU archivo (mínimo 8 pruebas)
└── scripts/
    ├── escenario_moduloA.js   multifirma e historial de emisores
    ├── escenario_moduloB.js   emisión individual y en lote, seguridad, pausa
    ├── escenario_moduloC.js   cifrado, ENLACE, Merkle, verificación
    └── integracion.js         los tres cursos juntos (semanas 3 y 4)
```

Las plantillas **compilan** pero revierten con `"TODO: ..."` hasta que se completan.
**Nadie tiene que programar JavaScript.** Los cuatro scripts vienen completos: solo se
ejecutan (clic derecho → Run). Todo lo que hay que programar está en Solidity. Mientras tu
contrato tenga funciones sin completar, el script se detendrá con el mensaje `TODO` de esa función.
Cada archivo de pruebas trae **dos pruebas resueltas** de ejemplo.

## 3. Cargar el proyecto en Remix

1. Abrir https://app.remix.live
2. En el desplegable del espacio de trabajo, elegir *Clone* y pegar:
   https://github.com/ser-web/sello-libertador
3. No subir carpetas a mano: la estructura se desordena.

## 4. Ajustes OBLIGATORIOS de Remix

| Dónde | Ajuste | Por qué |
|---|---|---|
| *Solidity Compiler* | Versión **0.8.20** | La misma de las clases anteriores; todos igual, para que el gas sea comparable |
| *Advanced configurations* | EVM **default** (no cambiarla) | Igual para todos |
| *Advanced configurations* | **Enable optimization: activado, 200 runs** | Sin optimizar, los contratos de prueba superan 24 KB |
| *Settings* | **Generate contract metadata: activado** | Los scripts leen `artifacts/` |
| *Deploy & Run* | Entorno **Remix VM** | Cadena simulada, sin costo |

## 5. Pruebas unitarias

1. Activar **Solidity Unit Testing** en el *Plugin Manager*.
2. Elegir la carpeta `tests`, marcar el archivo del curso y pulsar *Run*.
3. Cada función pública es una prueba; `beforeEach()` deja el estado limpio.

Cada prueba corre en **una sola transacción**: `block.timestamp` no cambia dentro
de ella. Las comprobaciones con fechas distintas van en los scripts.

## 6. Scripts

Compilar antes los contratos que indica la cabecera del script → clic derecho sobre
el script → **Run**. La salida aparece en la terminal, con una tabla de gas.

## 7. Reglas comunes

- No modificar `interfaces/`, `comun/` ni `simulacros/` sin acuerdo de los tres cursos.
- Ningún dato personal en la cadena.
- Localizador: 10 caracteres `[0-9A-Z]`, único para siempre, `bytes10` en Solidity.
- **Dos modos de emisión alternativos**: `RegistroTitulos` (un registro por título, revocable)
  y `AnclajeLotes` (una raíz por ceremonia, más barato, sin estado por título). Un mismo
  título no se emite en los dos modos.
- Pausa: se bloquea lo que **crea** títulos (`emitir`, `emitirLote`, `rectificar`); se permite
  lo que **invalida** (`suspender`, `revocar`) y `reactivar`.
- Hoja de Merkle: `keccak256(bytes.concat(keccak256(abi.encode(localizador, compromiso))))`.
- `loteId` empieza en 1; las propuestas de la multifirma, en 0.
- Periodos de autorización semiabiertos `[desde, hasta)`.
- Errores personalizados en lugar de cadenas de texto; eventos en todo cambio de estado.

## 8. Integración

1. Los tres equipos del consorcio reúnen sus archivos de `moduloA/`, `moduloB/` y
   `moduloC/` en un espacio de trabajo común.
2. Compilar los cinco contratos y ejecutar `scripts/integracion.js`.
3. Debe terminar con **«🎓 ESCENARIO DE ACEPTACIÓN SUPERADO»**.
4. Ensayo: si la multifirma no está lista, usar `SimMultifirmaUBO` (mismo constructor).

Al recargar Remix, la cadena vuelve a cero: basta con volver a ejecutar el script.

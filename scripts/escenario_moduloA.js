// ------------------------------------------------------------------
// _compat.js — Funciones auxiliares comunes a todos los scripts de Remix
// ------------------------------------------------------------------
// Remix no permite importar fácilmente un script desde otro, así que
// este bloque se COPIA al principio de cada script. Está aquí como
// referencia única: si se corrige algo, copiarlo de nuevo a los demás.
//
// Funciona con ethers v5 y v6 (según la versión que traiga Remix).
// Requisitos en Remix:
//   1. Entorno «Remix VM» seleccionado en «Deploy & Run Transactions».
//   2. Compilar ANTES los contratos que el script despliega.
//   3. En Ajustes (Settings) > «Generate contract metadata» ACTIVADO,
//      para que Remix cree las carpetas artifacts/.
// ------------------------------------------------------------------

// ethers está disponible como global en los scripts de Remix; si no, se importa.
const E = (typeof ethers !== 'undefined') ? ethers : require('ethers')
const V6 = typeof E.BrowserProvider === 'function'
const U = V6 ? E : E.utils

const proveedor = V6
  ? new E.BrowserProvider(web3Provider)
  : new E.providers.Web3Provider(web3Provider)

const cuenta = async (i) => await proveedor.getSigner(i)
const direccionDe = async (c) => (typeof c.getAddress === 'function' ? await c.getAddress() : c.address)
const abiCoder = V6 ? E.AbiCoder.defaultAbiCoder() : E.utils.defaultAbiCoder
const id = (texto) => U.keccak256(U.toUtf8Bytes(texto)) // equivale a keccak256("texto")

// Busca el artefacto compilado en las rutas habituales de Remix
async function artefacto (nombre, carpeta) {
  const rutas = [
    `${carpeta}/artifacts/${nombre}.json`,
    `contracts/artifacts/${nombre}.json`,
    `artifacts/${nombre}.json`
  ]
  for (const r of rutas) {
    try {
      const txt = await remix.call('fileManager', 'getFile', r)
      if (txt) return JSON.parse(txt)
    } catch (e) { /* probar la siguiente ruta */ }
  }
  throw new Error(`No encuentro el artefacto de ${nombre}. ¿Lo compilaste? ¿Está activado «Generate contract metadata»?`)
}

// Despliega un contrato y devuelve [instancia, gasUsado]
async function desplegar (nombre, carpeta, args = [], firmante = null) {
  const art = await artefacto(nombre, carpeta)
  const f = firmante || await cuenta(0)
  const fabrica = new E.ContractFactory(art.abi, art.data.bytecode.object, f)
  const c = await fabrica.deploy(...args)
  const tx = V6 ? c.deploymentTransaction() : c.deployTransaction
  const rc = await tx.wait()
  console.log(`✔ ${nombre} desplegado en ${await direccionDe(c)} — gas: ${rc.gasUsed.toString()}`)
  return [c, rc.gasUsed.toString()]
}

// Envía una transacción y devuelve el gas usado
async function enviar (etiqueta, promesaTx, tablaGas) {
  const tx = await promesaTx
  const rc = await tx.wait()
  const gas = rc.gasUsed.toString()
  console.log(`  · ${etiqueta} — gas: ${gas}`)
  if (tablaGas) tablaGas.push({ operacion: etiqueta, gas })
  return rc
}

// Comprueba que una llamada revierte
async function debeRevertir (etiqueta, promesa) {
  try {
    const tx = await promesa
    if (tx && tx.wait) await tx.wait()
    console.log(`  ✘ ${etiqueta}: NO revirtió y debía hacerlo`)
  } catch (e) {
    console.log(`  ✔ ${etiqueta}: revierte como se espera`)
  }
}

// ==================================================================
// escenario_moduloA.js — Curso A
// Despliega MultifirmaUBO (2 de 3) y RegistroEmisores, y autoriza,
// revoca y reautoriza emisores mediante la multifirma.
// Compilar antes: MultifirmaUBO, RegistroEmisores
// ==================================================================
;(async () => {
  try {
    const gas = []
    const [rector, secGeneral, vicerrector, emisorIng, emisorSal] =
      await Promise.all([0, 1, 2, 3, 4].map(cuenta))
    const dirs = await Promise.all([rector, secGeneral, vicerrector, emisorIng, emisorSal].map(direccionDe))
    const ING = id('ING'); const SAL = id('SAL')

    console.log('— Despliegue —')
    const [ms, gMs] = await desplegar('MultifirmaUBO', 'contracts/moduloA', [[dirs[0], dirs[1], dirs[2]], 2])
    gas.push({ operacion: 'desplegar MultifirmaUBO', gas: gMs })
    const dMs = await direccionDe(ms)
    const [reg, gReg] = await desplegar('RegistroEmisores', 'contracts/moduloA', [dMs])
    gas.push({ operacion: 'desplegar RegistroEmisores', gas: gReg })
    const dReg = await direccionDe(reg)

    // Proponer + 2 confirmaciones + ejecutar. Devuelve el id de la propuesta.
    let siguienteId = 0
    async function viaMultifirma (etiqueta, datos) {
      const pid = siguienteId++
      await enviar(`${etiqueta}: proponer`, ms.connect(rector).proponer(dReg, datos), gas)
      await enviar(`${etiqueta}: confirma rector`, ms.connect(rector).confirmar(pid), gas)
      await enviar(`${etiqueta}: confirma sec. general`, ms.connect(secGeneral).confirmar(pid), gas)
      await enviar(`${etiqueta}: ejecutar`, ms.connect(vicerrector).ejecutar(pid), gas)
    }

    console.log('— Autorizaciones —')
    await viaMultifirma('autorizar emisor ING', reg.interface.encodeFunctionData('autorizarEmisor', [dirs[3], ING]))
    await viaMultifirma('autorizar emisor SAL', reg.interface.encodeFunctionData('autorizarEmisor', [dirs[4], SAL]))
    console.log('  emisor ING autorizado en ING:', await reg.estaAutorizado(dirs[3], ING))
    console.log('  emisor ING autorizado en SAL:', await reg.estaAutorizado(dirs[3], SAL))

    console.log('— Controles —')
    await debeRevertir('autorizar sin multifirma', reg.connect(rector).autorizarEmisor(dirs[4], ING))
    await enviar('proponer (para probar umbral)', ms.connect(rector).proponer(dReg,
      reg.interface.encodeFunctionData('autorizarEmisor', [dirs[4], ING])), gas)
    const pUmbral = siguienteId++
    await enviar('confirma solo rector', ms.connect(rector).confirmar(pUmbral), gas)
    await debeRevertir('ejecutar con 1 de 2 firmas', ms.connect(rector).ejecutar(pUmbral))
    await debeRevertir('rector confirma dos veces', ms.connect(rector).confirmar(pUmbral))

    console.log('— Historial —')
    await new Promise(r => setTimeout(r, 2000)) // para que el periodo 1 dure al menos un segundo
    await viaMultifirma('revocar emisor SAL', reg.interface.encodeFunctionData('revocarEmisor', [dirs[4], SAL]))
    await new Promise(r => setTimeout(r, 2000))
    await viaMultifirma('reautorizar emisor SAL', reg.interface.encodeFunctionData('autorizarEmisor', [dirs[4], SAL]))
    const ps = await reg.periodos(dirs[4], SAL)
    console.log(`  periodos del emisor SAL: ${ps.length}`)
    ps.forEach((p, i) => console.log(`   [${i}] desde ${p.desde} hasta ${p.hasta} ${p.hasta.toString() === '0' ? '(abierto)' : ''}`))
    // Consultas históricas: un instante dentro de cada periodo y uno entre ambos
    if (ps.length === 2) {
      const n = (x) => Number(x.toString())
      const casos = [
        ['un segundo antes del periodo 1', n(ps[0].desde) - 1, false],
        ['al inicio del periodo 1', n(ps[0].desde), n(ps[0].hasta) > n(ps[0].desde)],
        ['al cierre del periodo 1 (excluido)', n(ps[0].hasta), n(ps[1].desde) <= n(ps[0].hasta)],
        ['dentro del periodo 2', n(ps[1].desde), true],
        ['mucho después (periodo abierto)', n(ps[1].desde) + 100000, true]
      ]
      for (const [etiqueta, momento, esperado] of casos) {
        const r = await reg.estabaAutorizado(dirs[4], SAL, momento)
        console.log(`  ${r === esperado ? '✔' : '✘'} estabaAutorizado ${etiqueta}: ${r}`)
      }
    }

    console.log('— Tabla de gas —'); console.table(gas)
  } catch (e) {
    console.error(e.message || e)
  }
})()

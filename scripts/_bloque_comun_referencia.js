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

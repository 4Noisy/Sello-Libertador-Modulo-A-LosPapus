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

// ====== UTILIDADES DE CREDENCIAL Y ENLACE (ya hechas: no hay que programar JavaScript) ======
// ------------------------------------------------------------------
// Utilidades de credencial, enlace sin billetera y Merkle (Módulo C)
// ------------------------------------------------------------------

// ---------- Canonicalización (RFC 8785, versión didáctica) ----------
function canonicalizar (valor) {
  if (valor === null || typeof valor !== 'object') return JSON.stringify(valor)
  if (Array.isArray(valor)) return '[' + valor.map(canonicalizar).join(',') + ']'
  const claves = Object.keys(valor).sort()
  return '{' + claves.map(k => JSON.stringify(k) + ':' + canonicalizar(valor[k])).join(',') + '}'
}

// hashDocumento = keccak256(bytes UTF-8 del JSON canonicalizado)
const hashDocumento = (credencial) => U.keccak256(U.toUtf8Bytes(canonicalizar(credencial)))

// compromiso = keccak256(abi.encode(sal, hashDocumento))
const compromiso = (sal, hashDoc) => U.keccak256(abiCoder.encode(['bytes32', 'bytes32'], [sal, hashDoc]))

const salAleatoria = () => U.hexlify(crypto.getRandomValues(new Uint8Array(32)))

// ---------- Localizador ----------
const ALFABETO = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' // 36 símbolos

// 10 caracteres aleatorios SIN sesgo de módulo: se descartan los bytes >= 252
// (252 = 7 × 36), porque 256 no es múltiplo de 36.
function generarLocalizador () {
  let loc = ''
  while (loc.length < 10) {
    const b = crypto.getRandomValues(new Uint8Array(1))[0]
    if (b < 252) loc += ALFABETO[b % 36]
  }
  return loc
}

// "U0ZSA8QPFN" -> 0x55305a5341385150464e (bytes10 para Solidity)
const aBytes10 = (loc) => U.hexlify(U.toUtf8Bytes(loc))

// ---------- base64url (RFC 4648, sección 5) ----------
function aBase64url (bytes) {
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
function deBase64url (txt) {
  const b64 = txt.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((txt.length + 3) % 4)
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0))
}

// ---------- Cifrado AES-256-GCM (Web Crypto) ----------
// ed = base64url(iv[12] || texto cifrado con etiqueta de autenticación)
async function cifrarDocumento (paquete) {
  const clave = crypto.getRandomValues(new Uint8Array(32))
  const iv = crypto.getRandomValues(new Uint8Array(12)) // NUNCA reutilizar un iv con la misma clave
  const k = await crypto.subtle.importKey('raw', clave, 'AES-GCM', false, ['encrypt'])
  const datos = new TextEncoder().encode(JSON.stringify(paquete))
  const cifrado = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, k, datos))
  const ed = new Uint8Array(iv.length + cifrado.length)
  ed.set(iv); ed.set(cifrado, iv.length)
  return { ed: aBase64url(ed), k: aBase64url(clave) }
}

async function descifrarDocumento (ed, kTxt) {
  const bytes = deBase64url(ed)
  const k = await crypto.subtle.importKey('raw', deBase64url(kTxt), 'AES-GCM', false, ['decrypt'])
  const claro = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: bytes.slice(0, 12) }, k, bytes.slice(12))
  return JSON.parse(new TextDecoder().decode(claro)) // falla si alguien alteró ed: GCM autentica
}

// ---------- Enlace del certificado ----------
// La clave va en el FRAGMENTO (#k=...): el navegador no la envía al servidor (RFC 3986, 3.5).
const PORTAL = 'https://verifica.ubo.cl/sello'
const construirEnlace = ({ sca, loc, tc, ed, k }) => `${PORTAL}?sca=${sca}&loc=${loc}&tc=${tc}&ed=${ed}#k=${k}`

function leerEnlace (enlace) {
  const [base, fragmento = ''] = enlace.split('#')
  const q = new URLSearchParams(base.split('?')[1] || '')
  const f = new URLSearchParams(fragmento)
  return { sca: q.get('sca'), loc: q.get('loc'), tc: q.get('tc'), ed: q.get('ed'), k: f.get('k') }
}

// ---------- Merkle (compatible con MerkleProof de OpenZeppelin) ----------
// hoja = keccak256(bytes.concat(keccak256(abi.encode(localizador, compromiso))))
const hojaLote = (loc, comp) =>
  U.keccak256(U.keccak256(abiCoder.encode(['bytes10', 'bytes32'], [aBytes10(loc), comp])))

function hashPar (a, b) {
  const [x, y] = BigInt(a) < BigInt(b) ? [a, b] : [b, a]
  return U.keccak256(U.concat([x, y]))
}

function construirArbol (hojas) {
  if (hojas.length === 0) throw new Error('Lote vacío')
  const niveles = [hojas.slice()]
  while (niveles[niveles.length - 1].length > 1) {
    const actual = niveles[niveles.length - 1]
    const siguiente = []
    for (let i = 0; i < actual.length; i += 2) {
      siguiente.push(i + 1 < actual.length ? hashPar(actual[i], actual[i + 1]) : actual[i])
    }
    niveles.push(siguiente)
  }
  return niveles
}
const raizDe = (niveles) => niveles[niveles.length - 1][0]
function pruebaDe (niveles, indice) {
  const prueba = []
  for (let n = 0; n < niveles.length - 1; n++) {
    const hermano = indice % 2 === 0 ? indice + 1 : indice - 1
    if (hermano < niveles[n].length) prueba.push(niveles[n][hermano])
    indice = Math.floor(indice / 2)
  }
  return prueba
}
function verificarPrueba (prueba, raiz, hoja) {
  let h = hoja
  for (const p of prueba) h = hashPar(h, p)
  return h === raiz
}

// ---------- Credencial de ejemplo (W3C VC 2.0 / Open Badges 3.0, simplificada) ----------
function credencialEjemplo (n) {
  return {
    '@context': ['https://www.w3.org/ns/credentials/v2'],
    type: ['VerifiableCredential', 'OpenBadgeCredential'],
    issuer: { id: 'did:web:ubo.cl', name: "Universidad Bernardo O'Higgins" },
    validFrom: '2026-12-15T12:00:00Z',
    credentialSubject: {
      nombre: `Titulado de Prueba ${n}`,
      achievement: {
        titulo: 'Ingeniero Civil en Informática',
        facultad: 'Ingeniería, Ciencia y Tecnología',
        programa: 'ING-INFORMATICA'
      }
    }
  }
}

// ---------- Verificación completa de un enlace (lo que haría el portal) ----------
// Ningún paso requiere billetera: solo lecturas de la cadena.
async function verificarEnlace (enlace, direccionOficial, verificador, abiRegistro) {
  const NOMBRES = ['Valido', 'Revocado', 'Suspendido', 'Inexistente', 'EmisorNoAutorizado', 'DocumentoAlterado']
  const e = leerEnlace(enlace)
  // 1. Anti-suplantación: el contrato del enlace debe ser el OFICIAL de la UBO
  if (!e.sca || e.sca.toLowerCase() !== direccionOficial.toLowerCase()) {
    return { veredicto: 'ContratoNoOficial', detalle: `sca=${e.sca}` }
  }
  // 2. Descifrar (si ed o k fueron alterados, AES-GCM lo detecta)
  let paquete
  try { paquete = await descifrarDocumento(e.ed, e.k) } catch (err) {
    return { veredicto: 'EnlaceCorrupto', detalle: 'no se pudo descifrar' }
  }
  // 3. Recalcular el compromiso y consultar el veredicto en la cadena
  const comp = compromiso(paquete.sal, hashDocumento(paquete.credencial))
  const veredicto = NOMBRES[Number(await verificador.verificar(aBytes10(e.loc), comp))]
  // 4. Comprobar que la transacción tc emitió ESTE localizador en ESTE contrato
  const rc = await proveedor.getTransactionReceipt(e.tc)
  const iface = new (E.Interface || E.utils.Interface)(abiRegistro)
  const emitido = !!rc && rc.logs.some(l => {
    if (l.address.toLowerCase() !== direccionOficial.toLowerCase()) return false
    try {
      const ev = iface.parseLog(l)
      return ev && ev.name === 'TituloEmitido' && ev.args.localizador.toLowerCase() === aBytes10(e.loc).toLowerCase()
    } catch (x) { return false }
  })
  return { veredicto, transaccionConfirma: emitido, titulo: paquete.credencial.credentialSubject.achievement.titulo }
}
// ====== FIN DE LAS UTILIDADES ======

// ==================================================================
// integracion.js — Semanas 3 y 4: los TRES cursos
// Despliega los módulos REALES y ejecuta el escenario de aceptación.
// Compilar antes: MultifirmaUBO, RegistroEmisores, RegistroTitulos,
//                 VerificadorUBO, AnclajeLotes, HerramientasSello
// Ensayo: si la multifirma no está lista, cambiar 'MultifirmaUBO', 'contracts/moduloA'
// por 'SimMultifirmaUBO', 'contracts/simulacros' (mismo constructor).
// ==================================================================
;(async () => {
  try {
    const gas = []
    const cuentas = await Promise.all([0, 1, 2, 3, 4].map(cuenta))
    const [rector, secGeneral, vicerrector, emisorIng, emisorSal] = cuentas
    const d = await Promise.all(cuentas.map(direccionDe))
    const ING = id('ING'); const SAL = id('SAL')
    let fallos = 0
    const esperar = (etiqueta, obtenido, esperado) => {
      const ok = String(obtenido) === String(esperado)
      if (!ok) fallos++
      console.log(`  ${ok ? '✔' : '✘'} ${etiqueta}: ${obtenido}${ok ? '' : ` (se esperaba ${esperado})`}`)
    }

    console.log('═══ 1. Despliegue en orden ═══')
    const [ms] = await desplegar('MultifirmaUBO', 'contracts/moduloA', [[d[0], d[1], d[2]], 2])
    const dMs = await direccionDe(ms)
    const [reg] = await desplegar('RegistroEmisores', 'contracts/moduloA', [dMs])
    const dReg = await direccionDe(reg)
    const [tit] = await desplegar('RegistroTitulos', 'contracts/moduloB', [dReg, dMs])
    const dTit = await direccionDe(tit) // dirección OFICIAL que la UBO publicaría
    const [ver] = await desplegar('VerificadorUBO', 'contracts/moduloC', [dTit, dReg])
    const [anc] = await desplegar('AnclajeLotes', 'contracts/moduloC', [dReg])
    const [her] = await desplegar('HerramientasSello', 'contracts/moduloC')
    const nuevoLoc = async () => U.toUtf8String(await her.derivarLocalizador(salAleatoria()))
    const abiTit = (await artefacto('RegistroTitulos', 'contracts/moduloB')).abi

    let pid = 0
    async function viaMultifirma (etiqueta, destino, datos) {
      const n = pid++
      await enviar(`${etiqueta}: proponer`, ms.connect(rector).proponer(destino, datos), gas)
      await enviar(`${etiqueta}: confirmar (1/2)`, ms.connect(rector).confirmar(n), gas)
      await enviar(`${etiqueta}: confirmar (2/2)`, ms.connect(secGeneral).confirmar(n), gas)
      await enviar(`${etiqueta}: ejecutar`, ms.connect(vicerrector).ejecutar(n), gas)
    }

    console.log('═══ 2. La multifirma autoriza emisores de ING y SAL ═══')
    await viaMultifirma('autorizar ING', dReg, reg.interface.encodeFunctionData('autorizarEmisor', [d[3], ING]))
    await viaMultifirma('autorizar SAL', dReg, reg.interface.encodeFunctionData('autorizarEmisor', [d[4], SAL]))

    console.log('═══ 3. Emisión con enlace sin billetera ═══')
    const t = []
    for (const [n, emisor, fac, prog] of [[1, emisorIng, ING, 'ING-INFORMATICA'], [2, emisorSal, SAL, 'SAL-ENFERMERIA']]) {
      const loc = await nuevoLoc(); const credencial = credencialEjemplo(n); const sal = salAleatoria()
      const comp = compromiso(sal, hashDocumento(credencial))
      const rc = await enviar(`emitir ${loc}`, tit.connect(emisor).emitir(aBytes10(loc), fac, id(prog), comp), gas)
      const { ed, k } = await cifrarDocumento({ credencial, sal })
      t.push({ loc, credencial, sal, comp, enlace: construirEnlace({ sca: dTit, loc, tc: rc.hash || rc.transactionHash, ed, k }) })
    }
    // Lote de 3 títulos adicionales en una sola transacción
    const lote = []
    for (let i = 0; i < 3; i++) {
      const credencial = credencialEjemplo(10 + i); const sal = salAleatoria()
      lote.push({ loc: await nuevoLoc(), credencial, sal, comp: compromiso(sal, hashDocumento(credencial)) })
    }
    await enviar('emitir lote de 3', tit.connect(emisorIng).emitirLote(lote.map(x => aBytes10(x.loc)), ING, id('ING-INFORMATICA'), lote.map(x => x.comp)), gas)
    console.log('  enlace de ejemplo:\n  ' + t[0].enlace)

    console.log('═══ 4. Modo económico: una ceremonia anclada con UNA raíz ═══')
    // Estos títulos NO se registran uno a uno en RegistroTitulos: es la ALTERNATIVA
    // de bajo costo. Se paga una sola transacción, sea cual sea el tamaño de la ceremonia.
    const ceremonia = []
    for (let i = 0; i < 8; i++) {
      const credencial = credencialEjemplo(100 + i); const sal = salAleatoria()
      ceremonia.push({ loc: await nuevoLoc(), comp: compromiso(sal, hashDocumento(credencial)) })
    }
    const hojasCer = ceremonia.map(x => hojaLote(x.loc, x.comp))
    const niveles = construirArbol(hojasCer)
    esperar('raíz de Merkle del contrato igual a la de referencia', (await her.raizDeMerkle(hojasCer)) === raizDe(niveles), true)
    await enviar('anclar ceremonia de 8 títulos (1 tx)', anc.connect(emisorIng).anclarLote(raizDe(niveles), ING, id('CEREMONIA-2026-12')), gas)
    esperar('inclusión del 6.º título de la ceremonia', await anc.verificarInclusion(1, aBytes10(ceremonia[5].loc), ceremonia[5].comp, pruebaDe(niveles, 5)), true)
    esperar('ese título no ocupa almacenamiento en RegistroTitulos', Number((await tit.obtenerTitulo(aBytes10(ceremonia[5].loc))).estado), 0)

    console.log('═══ 5. Verificación por enlace ═══')
    const v = async (enlace) => (await verificarEnlace(enlace, dTit, ver, abiTit))
    let r = await v(t[0].enlace)
    esperar('enlace correcto', r.veredicto, 'Valido'); esperar('tc confirma la emisión', r.transaccionConfirma, true)
    const alterado = await cifrarDocumento({ credencial: { ...t[0].credencial, validFrom: '2020-01-01T00:00:00Z' }, sal: t[0].sal })
    const e0 = leerEnlace(t[0].enlace)
    r = await v(construirEnlace({ ...e0, ed: alterado.ed, k: alterado.k }))
    esperar('documento alterado y recifrado', r.veredicto, 'DocumentoAlterado')
    r = await v(t[0].enlace.replace(dTit, dReg))
    esperar('contrato no oficial', r.veredicto, 'ContratoNoOficial')

    console.log('═══ 6. Revocación de un título ═══')
    await enviar('revocar lote[0]', tit.connect(emisorIng).revocar(aBytes10(lote[0].loc), 1), gas)
    esperar('título revocado', ['Valido', 'Revocado'][Number(await ver.verificar(aBytes10(lote[0].loc), lote[0].comp))], 'Revocado')

    console.log('═══ 7. Se revoca al emisor de SAL ═══')
    await new Promise(res => setTimeout(res, 2000)) // la revocación debe caer en un segundo posterior
    await viaMultifirma('revocar emisor SAL', dReg, reg.interface.encodeFunctionData('revocarEmisor', [d[4], SAL]))
    r = await v(t[1].enlace)
    esperar('título de SAL emitido antes sigue válido', r.veredicto, 'Valido')
    await debeRevertir('emisor SAL intenta emitir después', tit.connect(emisorSal).emitir(aBytes10(await nuevoLoc()), SAL, id('SAL-ENFERMERIA'), t[1].comp))

    console.log('═══ 8. Rectificación ═══')
    const locNuevo = await nuevoLoc(); const credCorr = { ...t[0].credencial, validFrom: '2026-12-16T12:00:00Z' }
    const salN = salAleatoria(); const compN = compromiso(salN, hashDocumento(credCorr))
    await enviar('rectificar', tit.connect(emisorIng).rectificar(aBytes10(t[0].loc), aBytes10(locNuevo), compN), gas)
    r = await v(t[0].enlace)
    esperar('enlace antiguo', r.veredicto, 'Revocado')
    const [, expl] = await ver.verificarConExplicacion(aBytes10(t[0].loc), t[0].comp)
    esperar('explicación menciona el nuevo localizador', expl.includes(locNuevo), true)

    console.log('═══ 9. Pausa de emergencia vía multifirma ═══')
    await viaMultifirma('pausar', dTit, tit.interface.encodeFunctionData('pausar', []))
    await debeRevertir('emitir en pausa', tit.connect(emisorIng).emitir(aBytes10(await nuevoLoc()), ING, id('X'), t[0].comp))
    await viaMultifirma('reanudar', dTit, tit.interface.encodeFunctionData('reanudar', []))

    console.log('═══ Tabla de gas del sistema ═══'); console.table(gas)
    console.log(fallos === 0 ? '🎓 ESCENARIO DE ACEPTACIÓN SUPERADO' : `⚠ ${fallos} comprobación(es) fallida(s)`)
  } catch (e) {
    console.error(e.message || e)
  }
})()

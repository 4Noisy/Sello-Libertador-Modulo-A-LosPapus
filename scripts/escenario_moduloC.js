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
// escenario_moduloC.js — Curso C
// Genera localizadores, cifra las credenciales, construye el ENLACE del
// certificado (sin billetera para el titulado), ancla una ceremonia en modo económico y
// verifica enlaces correctos, alterados y falsificados.
// Compilar antes: SimRegistroEmisores, SimRegistroTitulos, VerificadorUBO, AnclajeLotes, HerramientasSello
// ==================================================================
;(async () => {
  try {
    const gas = []
    const emisor = await cuenta(1)
    const ING = id('ING')

    console.log('— Despliegue (con simulacros) —')
    const [reg] = await desplegar('SimRegistroEmisores', 'contracts/simulacros')
    const [tit] = await desplegar('SimRegistroTitulos', 'contracts/simulacros')
    const dReg = await direccionDe(reg); const dTit = await direccionDe(tit)
    const [ver] = await desplegar('VerificadorUBO', 'contracts/moduloC', [dTit, dReg])
    const [anc] = await desplegar('AnclajeLotes', 'contracts/moduloC', [dReg])
    const [her] = await desplegar('HerramientasSello', 'contracts/moduloC')
    await enviar('autorizar emisor (simulacro)', reg.autorizarEmisor(await direccionDe(emisor), ING), gas)
    const abiTitulos = (await artefacto('SimRegistroTitulos', 'contracts/simulacros')).abi

    console.log('— Emisión y enlaces —')
    const titulos = []
    for (let n = 1; n <= 4; n++) {
      // El localizador lo deriva TU contrato a partir de una semilla aleatoria
      const loc = U.toUtf8String(await her.derivarLocalizador(salAleatoria()))
      const credencial = credencialEjemplo(n)
      const sal = salAleatoria()
      const comp = compromiso(sal, hashDocumento(credencial))
      const rc = await enviar(`emitir ${loc}`, tit.connect(emisor).emitir(aBytes10(loc), ING, id('ING-INFORMATICA'), comp), gas)
      const { ed, k } = await cifrarDocumento({ credencial, sal })
      const enlace = construirEnlace({ sca: dTit, loc, tc: rc.hash || rc.transactionHash, ed, k })
      titulos.push({ loc, credencial, sal, comp, enlace })
    }
    console.log('  Enlace del título 1 (lo que recibe el titulado por correo o QR):\n  ' + titulos[0].enlace)

    console.log('— Modo económico: ceremonia anclada con UNA raíz —')
    // Títulos DISTINTOS de los anteriores: no se registran uno a uno.
    const ceremonia = Array.from({ length: 8 }, (_, i) => {
      const credencial = credencialEjemplo(100 + i); const sal = salAleatoria()
      return { loc: generarLocalizador(), comp: compromiso(sal, hashDocumento(credencial)) }
    })
    const hojas = ceremonia.map(t => hojaLote(t.loc, t.comp))
    const niveles = construirArbol(hojas)
    const raizSol = await her.raizDeMerkle(hojas)
    console.log(`  raíz calculada por tu contrato igual a la de referencia: ${raizSol === raizDe(niveles) ? 'OK' : 'ERROR'}`)
    console.log(`  comprobación local de las 8 pruebas: ${hojas.every((h, i) => verificarPrueba(pruebaDe(niveles, i), raizDe(niveles), h)) ? 'OK' : 'ERROR'}`)
    await enviar('anclar ceremonia de 8 (1 tx)', anc.connect(emisor).anclarLote(raizDe(niveles), ING, id('CEREMONIA-2026-12')), gas)
    console.log('  inclusión del título 3:', await anc.verificarInclusion(1, aBytes10(ceremonia[2].loc), ceremonia[2].comp, pruebaDe(niveles, 2)))
    console.log('  PREGUNTA DE DISEÑO: compara el gas de «anclar ceremonia de 8» con 8 emisiones individuales.')
    console.log('  ¿Qué se pierde en el modo económico? (pista: ¿cómo revocarías UNO de esos 8 títulos?)')

    console.log('— Verificación de enlaces (sin billetera) —')
    const v = (enlace, oficial = dTit) => verificarEnlace(enlace, oficial, ver, abiTitulos)
    console.log('  1) enlace correcto           →', await v(titulos[0].enlace))
    const e = leerEnlace(titulos[0].enlace)
    const edAlterado = e.ed.slice(0, 20) + (e.ed[20] === 'A' ? 'B' : 'A') + e.ed.slice(21)
    console.log('  2) ed alterado               →', await v(titulos[0].enlace.replace(e.ed, edAlterado)))
    const [falsoReg] = await desplegar('SimRegistroTitulos', 'contracts/simulacros')
    console.log('  3) contrato no oficial (sca) →', await v(titulos[0].enlace.replace(dTit, await direccionDe(falsoReg))))
    const ajeno = await cifrarDocumento({ credencial: titulos[1].credencial, sal: titulos[1].sal })
    const mezcla = construirEnlace({ sca: dTit, loc: titulos[0].loc, tc: leerEnlace(titulos[0].enlace).tc, ed: ajeno.ed, k: ajeno.k })
    console.log('  4) documento de otro título  →', await v(mezcla))
    await enviar('revocar título 2 (simulacro)', tit.revocar(aBytes10(titulos[1].loc), 2), gas)
    console.log('  5) título revocado           →', await v(titulos[1].enlace))
    const eAjena = leerEnlace(titulos[2].enlace)
    const tcAjena = construirEnlace({ ...leerEnlace(titulos[3].enlace), tc: eAjena.tc })
    console.log('  6) tc de otra transacción    →', await v(tcAjena))
    await enviar('mover el periodo del emisor al futuro (simulacro)', reg.fijarPeriodo(await direccionDe(emisor), ING, 9999999999, 0), gas)
    console.log('  7) emisor no autorizado      →', await v(titulos[3].enlace))

    console.log('— Tabla de gas —'); console.table(gas)
  } catch (err) {
    console.error(err.message || err)
  }
})()

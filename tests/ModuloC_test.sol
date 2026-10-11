// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/moduloC/VerificadorUBO.sol";
import "../contracts/moduloC/AnclajeLotes.sol";
import "../contracts/moduloC/HerramientasSello.sol";
import "../contracts/simulacros/SimRegistroEmisores.sol";
import "../contracts/simulacros/SimRegistroTitulos.sol";
import "../contracts/comun/ConstantesUBO.sol";

/// @title Pruebas del Módulo C — PLANTILLA (Curso C)
/// @notice Usa SimRegistroEmisores y SimRegistroTitulos en lugar de los módulos reales.
///         Mínimo 8 pruebas. Dos están resueltas como ejemplo; completar el resto.
contract ModuloCTest {
    SimRegistroEmisores registro;
    SimRegistroTitulos titulos;
    VerificadorUBO verificador;
    AnclajeLotes anclaje;
    HerramientasSello herramientas;
    address emisorIng = address(0xB1);
    bytes10 constant L1 = bytes10("U0ZSA8QPFN");
    bytes32 constant SAL_ = bytes32(uint256(111));
    bytes32 constant HASH_DOC = keccak256('{"programa":"ING-INFORMATICA"}');

    function beforeEach() public {
        registro = new SimRegistroEmisores();
        titulos = new SimRegistroTitulos();
        verificador = new VerificadorUBO(address(titulos), address(registro));
        anclaje = new AnclajeLotes(address(registro));
        herramientas = new HerramientasSello();
    }

    /// @dev Fabrica un título con el simulacro: emitido por emisorIng hace 100 s,
    ///      con un periodo de autorización que lo cubre.
    function _tituloValido(bytes10 loc) internal returns (bytes32 compromiso) {
        compromiso = ConstantesUBO.compromiso(SAL_, HASH_DOC);
        uint64 fecha = uint64(block.timestamp - 100);
        registro.fijarPeriodo(emisorIng, ConstantesUBO.ING, fecha - 1000, 0);
        titulos.fijarTitulo(loc, IRegistroTitulos.Titulo({
            compromiso: compromiso,
            emisor: emisorIng,
            facultad: ConstantesUBO.ING,
            codigoPrograma: keccak256("ING-INFORMATICA"),
            fechaEmision: fecha,
            estado: IRegistroTitulos.Estado.Emitido,
            motivo: 0,
            rectificadoComo: bytes10(0)
        }));
    }

    // ---------- EJEMPLO 1 (resuelto) ----------
    function veredictoValido() public {
        bytes32 c = _tituloValido(L1);
        Assert.equal(uint256(verificador.verificar(L1, c)),
            uint256(IVerificadorUBO.Veredicto.Valido), "Debe ser valido");
    }

    // ---------- EJEMPLO 2 (resuelto) ----------
    function documentoAlteradoUnCaracter() public {
        _tituloValido(L1);
        bytes32 alterado = ConstantesUBO.compromiso(SAL_, keccak256('{"programa":"ING-INFORMATICB"}'));
        Assert.equal(uint256(verificador.verificar(L1, alterado)),
            uint256(IVerificadorUBO.Veredicto.DocumentoAlterado), "Debe detectar la alteracion");
    }

    // ---------- PRUEBAS OBLIGATORIAS (completar) ----------
    function veredictosInexistenteYEmisorNoAutorizado() public {
        // TODO: un localizador nunca emitido -> Inexistente;
        //       fijarPeriodo() que empiece DESPUÉS de fechaEmision -> EmisorNoAutorizado
        Assert.ok(false, "TODO");
    }

    function veredictosRevocadoSuspendidoYOrden() public {
        // TODO: suspender -> Suspendido; revocar -> Revocado;
        //       un título revocado Y con documento alterado debe dar Revocado
        Assert.ok(false, "TODO");
    }

    function explicacionDeRectificacion() public {
        // TODO: rectificar L1 a otro localizador con el simulacro y comprobar que
        //       verificarConExplicacion(L1, ...) menciona el nuevo localizador
        Assert.ok(false, "TODO");
    }

    function loteYPruebasDeInclusion() public {
        // TODO: árbol de 2 hojas con ConstantesUBO.hojaLote; anclar la raíz (autorizar antes
        //       a address(this) en ING); la prueba correcta da true, una falsa da false,
        //       y un emisor no autorizado no puede anclar
        Assert.ok(false, "TODO");
    }

    function localizadorSinSesgo() public {
        // TODO (a): recorrer los 256 valores de un byte; contar, para cada uno de los 36
        //           símbolos, cuántos bytes ACEPTADOS le corresponden. Los 36 contadores
        //           deben valer lo mismo. Es una prueba exacta de que no hay sesgo.
        // TODO (b): derivarLocalizador(semilla) devuelve 10 símbolos del alfabeto, es
        //           determinista y cambia si cambia la semilla
        Assert.ok(false, "TODO");
    }

    function raizDeMerkleEnSolidity() public {
        // TODO: con 3 hojas h1, h2, h3: la raíz debe ser par(par(h1, h2), h3), donde par()
        //       ordena sus dos argumentos. Con 1 hoja, la raíz es la propia hoja.
        //       Con 0 hojas, revierte.
        Assert.ok(false, "TODO");
    }
}

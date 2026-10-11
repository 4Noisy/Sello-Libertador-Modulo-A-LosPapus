// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Estas dos bibliotecas las proporciona Remix automáticamente al ejecutar las pruebas.
import "remix_tests.sol";
import "../contracts/moduloA/MultifirmaUBO.sol";
import "../contracts/moduloA/RegistroEmisores.sol";
import "../contracts/comun/ActorPruebas.sol";
import "../contracts/comun/ConstantesUBO.sol";

/// @title Pruebas del Módulo A — PLANTILLA (Curso A)
/// @notice Ejecutar desde el complemento «Solidity Unit Testing» de Remix.
///         Mínimo 8 pruebas. Dos están resueltas como ejemplo; completar el resto.
contract ModuloATest {
    MultifirmaUBO multifirma;
    RegistroEmisores registro;
    ActorPruebas rector;
    ActorPruebas secGeneral;
    ActorPruebas vicerrector;
    ActorPruebas intruso;
    address emisorIng = address(0xB1);

    /// @dev Remix ejecuta beforeEach() antes de CADA prueba: estado limpio.
    function beforeEach() public {
        rector = new ActorPruebas();
        secGeneral = new ActorPruebas();
        vicerrector = new ActorPruebas();
        intruso = new ActorPruebas();

        address[] memory firmantes = new address[](3);
        firmantes[0] = address(rector);
        firmantes[1] = address(secGeneral);
        firmantes[2] = address(vicerrector);
        multifirma = new MultifirmaUBO(firmantes, 2); // 2 de 3
        registro = new RegistroEmisores(address(multifirma));
    }

    // ---------- Auxiliares ----------
    function _proponer(ActorPruebas quien, bytes memory datosRegistro) internal returns (uint256 id) {
        bytes memory r = quien.llamar(
            address(multifirma),
            abi.encodeCall(IMultifirmaUBO.proponer, (address(registro), datosRegistro))
        );
        id = abi.decode(r, (uint256));
    }

    function _confirmar(ActorPruebas quien, uint256 id) internal {
        quien.llamar(address(multifirma), abi.encodeCall(IMultifirmaUBO.confirmar, (id)));
    }

    function _ejecutar(ActorPruebas quien, uint256 id) internal {
        quien.llamar(address(multifirma), abi.encodeCall(IMultifirmaUBO.ejecutar, (id)));
    }

    function autorizacionConDosFirmas() public {
        uint256 id = _proponer(rector,
            abi.encodeCall(IRegistroEmisores.autorizarEmisor, (emisorIng, ConstantesUBO.ING)));
        _confirmar(rector, id);
        _confirmar(secGeneral, id);
        _ejecutar(vicerrector, id);
        Assert.ok(registro.estaAutorizado(emisorIng, ConstantesUBO.ING), "Debe quedar autorizado");
        Assert.ok(!registro.estaAutorizado(emisorIng, ConstantesUBO.SAL), "Solo en su facultad");
    }

    function umbralNoAlcanzadoRevierte() public {
        uint256 id = _proponer(rector,
            abi.encodeCall(IRegistroEmisores.autorizarEmisor, (emisorIng, ConstantesUBO.ING)));
        _confirmar(rector, id);
        try rector.llamar(address(multifirma), abi.encodeCall(IMultifirmaUBO.ejecutar, (id))) {
            Assert.ok(false, "Con 1 de 2 firmas no debe ejecutarse");
        } catch {
            Assert.ok(true, "Revierte como se espera");
        }
    }

    function dobleConfirmacionRevierte() public {
        // TODO: un mismo firmante confirma dos veces -> debe revertir
        Assert.ok(false, "TODO");
    }

    function ejecucionRepetidaRevierte() public {
        // TODO: ejecutar dos veces la misma propuesta -> la segunda revierte
        Assert.ok(false, "TODO");
    }

    function noFirmanteNoPuedeProponer() public {
        // TODO: `intruso` intenta proponer -> revierte
        Assert.ok(false, "TODO");
    }

    function registroSoloAceptaMultifirma() public {
        // TODO: llamar a registro.autorizarEmisor directamente (sin multifirma) -> revierte
        Assert.ok(false, "TODO");
    }

    function revocacionYReautorizacion() public {
        // TODO: autorizar, revocar y volver a autorizar; comprobar estaAutorizado en cada paso
        //       y que periodos() devuelve 2 periodos
        Assert.ok(false, "TODO");
    }

    function consultaHistoricaEstabaAutorizado() public {
        // TODO: comprobar los BORDES de estabaAutorizado().
        // ATENCIÓN: en Remix, cada función de prueba se ejecuta en UNA sola transacción,
        //   así que block.timestamp no cambia dentro de la prueba y no se puede «viajar en
        //   el tiempo». Con t = block.timestamp, comprobar al menos:
        //     - autorizar en t:            estabaAutorizado(t - 1) == false
        //                                  estabaAutorizado(t)     == true
        //                                  estabaAutorizado(t + 1000) == true (periodo abierto)
        //     - revocar en el mismo t:     el periodo queda [t, t), vacío -> estabaAutorizado(t) == false
        //     - reautorizar en t:          estabaAutorizado(t) == true de nuevo
        //   La comprobación con momentos DISTINTOS (antes, durante y después de un periodo
        //   cerrado) se hace en el script escenario_moduloA.js, donde cada transacción es
        //   un bloque nuevo con la hora real.
        Assert.ok(false, "TODO");
    }
}

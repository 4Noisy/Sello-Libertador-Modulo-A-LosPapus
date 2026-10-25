// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Estas dos bibliotecas las proporciona Remix automáticamente al ejecutar las pruebas.
import "remix_tests.sol";
import "../contracts/moduloA/MultifirmaUBO.sol";
import "../contracts/moduloA/RegistroEmisores.sol";
import "../contracts/comun/ActorPruebas.sol";
import "../contracts/comun/ConstantesUBO.sol";

/// @title Pruebas del Módulo A (Curso A)
/// @notice Ejecutar desde el complemento «Solidity Unit Testing» de Remix.
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

    /// @dev Propone, confirma con 2 firmantes y ejecuta una llamada al registro.
    function _aprobar(bytes memory datosRegistro) internal returns (uint256 id) {
        id = _proponer(rector, datosRegistro);
        _confirmar(rector, id);
        _confirmar(secGeneral, id);
        _ejecutar(vicerrector, id);
    }

    // ---------- EJEMPLO 1 (resuelto) ----------
    function autorizacionConDosFirmas() public {
        uint256 id = _proponer(rector,
            abi.encodeCall(IRegistroEmisores.autorizarEmisor, (emisorIng, ConstantesUBO.ING)));
        _confirmar(rector, id);
        _confirmar(secGeneral, id);
        _ejecutar(vicerrector, id);
        Assert.ok(registro.estaAutorizado(emisorIng, ConstantesUBO.ING), "Debe quedar autorizado");
        Assert.ok(!registro.estaAutorizado(emisorIng, ConstantesUBO.SAL), "Solo en su facultad");
    }

    // ---------- EJEMPLO 2 (resuelto): comprobar una reversión ----------
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

    // ---------- PRUEBAS OBLIGATORIAS ----------
    function dobleConfirmacionRevierte() public {
        uint256 id = _proponer(rector,
            abi.encodeCall(IRegistroEmisores.autorizarEmisor, (emisorIng, ConstantesUBO.ING)));
        _confirmar(rector, id);
        try rector.llamar(address(multifirma), abi.encodeCall(IMultifirmaUBO.confirmar, (id))) {
            Assert.ok(false, "Un firmante no debe confirmar dos veces");
        } catch {
            Assert.ok(true, "Revierte como se espera");
        }
        Assert.equal(multifirma.numeroConfirmaciones(id), uint256(1), "Debe seguir con 1 confirmacion");
    }

    function ejecucionRepetidaRevierte() public {
        uint256 id = _aprobar(
            abi.encodeCall(IRegistroEmisores.autorizarEmisor, (emisorIng, ConstantesUBO.ING)));
        try vicerrector.llamar(address(multifirma), abi.encodeCall(IMultifirmaUBO.ejecutar, (id))) {
            Assert.ok(false, "Una propuesta no debe ejecutarse dos veces");
        } catch {
            Assert.ok(true, "Revierte como se espera");
        }
    }

    function noFirmanteNoPuedeProponer() public {
        bytes memory datos =
            abi.encodeCall(IRegistroEmisores.autorizarEmisor, (emisorIng, ConstantesUBO.ING));
        try intruso.llamar(
            address(multifirma),
            abi.encodeCall(IMultifirmaUBO.proponer, (address(registro), datos))
        ) {
            Assert.ok(false, "Un no firmante no debe poder proponer");
        } catch {
            Assert.ok(true, "Revierte como se espera");
        }
    }

    function registroSoloAceptaMultifirma() public {
        // Llama al registro directamente: msg.sender es este contrato de pruebas,
        // no la multifirma.
        try registro.autorizarEmisor(emisorIng, ConstantesUBO.ING) {
            Assert.ok(false, "El registro solo debe aceptar a la multifirma");
        } catch {
            Assert.ok(true, "Revierte como se espera");
        }
        Assert.ok(!registro.estaAutorizado(emisorIng, ConstantesUBO.ING), "No debe quedar autorizado");
    }

    function revocacionYReautorizacion() public {
        bytes memory autorizar =
            abi.encodeCall(IRegistroEmisores.autorizarEmisor, (emisorIng, ConstantesUBO.ING));
        bytes memory revocar =
            abi.encodeCall(IRegistroEmisores.revocarEmisor, (emisorIng, ConstantesUBO.ING));

        _aprobar(autorizar);
        Assert.ok(registro.estaAutorizado(emisorIng, ConstantesUBO.ING), "Autorizado tras autorizar");

        _aprobar(revocar);
        Assert.ok(!registro.estaAutorizado(emisorIng, ConstantesUBO.ING), "No autorizado tras revocar");

        _aprobar(autorizar);
        Assert.ok(registro.estaAutorizado(emisorIng, ConstantesUBO.ING), "Autorizado de nuevo");

        Assert.equal(
            registro.periodos(emisorIng, ConstantesUBO.ING).length,
            uint256(2),
            "Debe haber 2 periodos"
        );
    }

    function consultaHistoricaEstabaAutorizado() public {
        uint256 t = block.timestamp;
        bytes memory autorizar =
            abi.encodeCall(IRegistroEmisores.autorizarEmisor, (emisorIng, ConstantesUBO.ING));
        bytes memory revocar =
            abi.encodeCall(IRegistroEmisores.revocarEmisor, (emisorIng, ConstantesUBO.ING));

        // Autorizar en t: periodo abierto [t, 0)
        _aprobar(autorizar);
        Assert.ok(!registro.estabaAutorizado(emisorIng, ConstantesUBO.ING, t - 1), "Antes de t: no");
        Assert.ok(registro.estabaAutorizado(emisorIng, ConstantesUBO.ING, t), "En t: si");
        Assert.ok(registro.estabaAutorizado(emisorIng, ConstantesUBO.ING, t + 1000), "Periodo abierto: si");

        // Revocar en el mismo t: el periodo queda [t, t), vacio
        _aprobar(revocar);
        Assert.ok(!registro.estabaAutorizado(emisorIng, ConstantesUBO.ING, t), "Periodo vacio: no");

        // Reautorizar en t: nuevo periodo abierto
        _aprobar(autorizar);
        Assert.ok(registro.estabaAutorizado(emisorIng, ConstantesUBO.ING, t), "Reautorizado: si");
    }
}
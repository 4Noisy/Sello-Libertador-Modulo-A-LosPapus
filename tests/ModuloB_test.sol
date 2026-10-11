// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/moduloB/RegistroTitulos.sol";
import "../contracts/simulacros/SimRegistroEmisores.sol";
import "../contracts/comun/ActorPruebas.sol";
import "../contracts/comun/ConstantesUBO.sol";

/// @title Pruebas del Módulo B — PLANTILLA (Curso B)
/// @notice Usa SimRegistroEmisores en lugar del registro real del Curso A.
///         El propio contrato de prueba actúa como `administracion` (para la pausa).
///         Mínimo 8 pruebas. Dos están resueltas como ejemplo; completar el resto.
contract ModuloBTest {
    SimRegistroEmisores registro;
    RegistroTitulos titulos;
    ActorPruebas emisorIng;
    ActorPruebas emisorSal;
    bytes32 constant PROGRAMA = keccak256("ING-INFORMATICA");
    bytes32 constant COMPROMISO = bytes32(uint256(0x1234));
    bytes10 constant L1 = bytes10("U0ZSA8QPFN");
    bytes10 constant L2 = bytes10("K7M2Q9XR4T");
    bytes10 constant L3 = bytes10("B3N8V1C6Z0");

    function beforeEach() public {
        registro = new SimRegistroEmisores();
        titulos = new RegistroTitulos(address(registro), address(this));
        emisorIng = new ActorPruebas();
        emisorSal = new ActorPruebas();
        registro.autorizarEmisor(address(emisorIng), ConstantesUBO.ING);
        registro.autorizarEmisor(address(emisorSal), ConstantesUBO.SAL);
    }

    function _emitir(ActorPruebas quien, bytes10 loc, bytes32 facultad) internal {
        quien.llamar(address(titulos),
            abi.encodeCall(IRegistroTitulos.emitir, (loc, facultad, PROGRAMA, COMPROMISO)));
    }

    // ---------- EJEMPLO 1 (resuelto) ----------
    function emisionCorrecta() public {
        _emitir(emisorIng, L1, ConstantesUBO.ING);
        IRegistroTitulos.Titulo memory t = titulos.obtenerTitulo(L1);
        Assert.equal(uint256(t.estado), uint256(IRegistroTitulos.Estado.Emitido), "Estado inicial");
        Assert.equal(t.compromiso, COMPROMISO, "Compromiso guardado");
        Assert.equal(t.emisor, address(emisorIng), "Emisor registrado");
        Assert.equal(titulos.totalTitulos(), 1, "Contador");
    }

    // ---------- EJEMPLO 2 (resuelto) ----------
    function localizadorRepetidoRevierte() public {
        _emitir(emisorIng, L1, ConstantesUBO.ING);
        try emisorIng.llamar(address(titulos),
            abi.encodeCall(IRegistroTitulos.emitir, (L1, ConstantesUBO.ING, PROGRAMA, bytes32(uint256(9)))))
        {
            Assert.ok(false, "Un localizador no puede reutilizarse");
        } catch {
            Assert.equal(titulos.obtenerTitulo(L1).compromiso, COMPROMISO, "No se sobrescribe");
        }
    }

    // ---------- PRUEBAS OBLIGATORIAS (completar) ----------
    function localizadorConFormatoInvalido() public {
        // TODO: minúsculas ("u0zsa8qpfn"), menos de 10 caracteres (bytes10("ABC")) -> revierten
        Assert.ok(false, "TODO");
    }

    function emisorDeOtraFacultad() public {
        // TODO: emisorSal no puede emitir en ING ni revocar un título de ING
        Assert.ok(false, "TODO");
    }

    function loteCorrectoYTodoONada() public {
        // TODO: un lote de 3 válido registra 3; un lote con un localizador repetido
        //       DENTRO del lote revierte y no registra ninguno (totalTitulos no cambia)
        Assert.ok(false, "TODO");
    }

    function loteInvalido() public {
        // TODO: largos distintos, lote vacío y lote de MAX_LOTE + 1 -> revierten
        Assert.ok(false, "TODO");
    }

    function cicloDeVidaYRectificacion() public {
        // TODO: suspender -> reactivar -> rectificar; el anterior queda Revocado con
        //       MOTIVO_RECTIFICACION y rectificadoComo apunta al nuevo; revocado no se reactiva
        Assert.ok(false, "TODO");
    }

    function pausaDeEmergencia() public {
        // TODO: un actor que no es administración no puede pausar; en pausa no se emite
        //       pero sí se revoca; tras reanudar se vuelve a emitir.
        //       (Este contrato de prueba ES la administración: puede llamar titulos.pausar())
        Assert.ok(false, "TODO");
    }
}

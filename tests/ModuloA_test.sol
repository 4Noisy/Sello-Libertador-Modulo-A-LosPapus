 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/moduloA/MultifirmaUBO.sol";
import "../contracts/moduloA/RegistroEmisores.sol";
import "../contracts/comun/ActorPruebas.sol";
import "../contracts/comun/ConstantesUBO.sol";
import "../contracts/interfaces/IMultifirmaUBO.sol";
import "../contracts/interfaces/IRegistroEmisores.sol";

/// @title Pruebas del Modulo A (Curso A)
/// @notice Pruebas unitarias para Remix Solidity Unit Testing.
contract ModuloATest {
    MultifirmaUBO multifirma;
    RegistroEmisores registro;

    ActorPruebas rector;
    ActorPruebas secGeneral;
    ActorPruebas vicerrector;
    ActorPruebas intruso;

    address emisorIng = address(0xB1);

    /// @dev Remix ejecuta beforeEach antes de cada prueba.
    function beforeEach() public {
        rector = new ActorPruebas();
        secGeneral = new ActorPruebas();
        vicerrector = new ActorPruebas();
        intruso = new ActorPruebas();

        address[] memory firmantes = new address[](3);
        firmantes[0] = address(rector);
        firmantes[1] = address(secGeneral);
        firmantes[2] = address(vicerrector);

        multifirma = new MultifirmaUBO(firmantes, 2);
        registro = new RegistroEmisores(address(multifirma));
    }

    // =========================================================
    // FUNCIONES AUXILIARES
    // =========================================================

    function _datosAutorizar(address emisor, bytes32 facultad)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            IRegistroEmisores.autorizarEmisor,
            (emisor, facultad)
        );
    }

    function _datosRevocar(address emisor, bytes32 facultad)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            IRegistroEmisores.revocarEmisor,
            (emisor, facultad)
        );
    }

    function _proponer(
        ActorPruebas quien,
        bytes memory datosRegistro
    ) internal returns (uint256 id) {
        bytes memory resultado = quien.llamar(
            address(multifirma),
            abi.encodeCall(
                IMultifirmaUBO.proponer,
                (address(registro), datosRegistro)
            )
        );

        id = abi.decode(resultado, (uint256));
    }

    function _confirmar(ActorPruebas quien, uint256 id) internal {
        quien.llamar(
            address(multifirma),
            abi.encodeCall(IMultifirmaUBO.confirmar, (id))
        );
    }

    function _ejecutar(ActorPruebas quien, uint256 id) internal {
        quien.llamar(
            address(multifirma),
            abi.encodeCall(IMultifirmaUBO.ejecutar, (id))
        );
    }

    /// @dev Propone, obtiene dos confirmaciones y ejecuta.
    function _aprobar(bytes memory datosRegistro)
        internal
        returns (uint256 id)
    {
        id = _proponer(rector, datosRegistro);

        _confirmar(rector, id);
        _confirmar(secGeneral, id);

        _ejecutar(vicerrector, id);
    }

    // =========================================================
    // PRUEBA 1: AUTORIZACION CON DOS FIRMAS
    // =========================================================

    function autorizacionConDosFirmas() public {
        uint256 id = _proponer(
            rector,
            _datosAutorizar(emisorIng, ConstantesUBO.ING)
        );

        _confirmar(rector, id);
        _confirmar(secGeneral, id);
        _ejecutar(vicerrector, id);

        Assert.ok(
            registro.estaAutorizado(emisorIng, ConstantesUBO.ING),
            "Debe quedar autorizado en ING"
        );

        Assert.ok(
            !registro.estaAutorizado(emisorIng, ConstantesUBO.SAL),
            "No debe quedar autorizado en SAL"
        );
    }

    // =========================================================
    // PRUEBA 2: EL UMBRAL NO ALCANZADO REVIERTE
    // =========================================================

    function umbralNoAlcanzadoRevierte() public {
        uint256 id = _proponer(
            rector,
            _datosAutorizar(emisorIng, ConstantesUBO.ING)
        );

        _confirmar(rector, id);

        try rector.llamar(
            address(multifirma),
            abi.encodeCall(IMultifirmaUBO.ejecutar, (id))
        ) {
            Assert.ok(
                false,
                "Con una firma no debe ejecutarse"
            );
        } catch {
            Assert.ok(true, "La ejecucion debe revertir");
        }

        Assert.ok(
            !registro.estaAutorizado(emisorIng, ConstantesUBO.ING),
            "El emisor no debe quedar autorizado"
        );
    }

    // =========================================================
    // PRUEBA 3: DOBLE CONFIRMACION REVIERTE
    // =========================================================

    function dobleConfirmacionRevierte() public {
        uint256 id = _proponer(
            rector,
            _datosAutorizar(emisorIng, ConstantesUBO.ING)
        );

        _confirmar(rector, id);

        try rector.llamar(
            address(multifirma),
            abi.encodeCall(IMultifirmaUBO.confirmar, (id))
        ) {
            Assert.ok(
                false,
                "Un firmante no debe confirmar dos veces"
            );
        } catch {
            Assert.ok(
                true,
                "La segunda confirmacion debe revertir"
            );
        }

        Assert.equal(
            multifirma.numeroConfirmaciones(id),
            uint256(1),
            "Debe seguir existiendo una confirmacion"
        );
    }

    // =========================================================
    // PRUEBA 4: EJECUCION REPETIDA REVIERTE
    // =========================================================

    function ejecucionRepetidaRevierte() public {
        uint256 id = _aprobar(
            _datosAutorizar(emisorIng, ConstantesUBO.ING)
        );

        try vicerrector.llamar(
            address(multifirma),
            abi.encodeCall(IMultifirmaUBO.ejecutar, (id))
        ) {
            Assert.ok(
                false,
                "La propuesta no debe ejecutarse dos veces"
            );
        } catch {
            Assert.ok(
                true,
                "La segunda ejecucion debe revertir"
            );
        }

        Assert.ok(
            registro.estaAutorizado(emisorIng, ConstantesUBO.ING),
            "La primera ejecucion debe conservar su efecto"
        );
    }

    // =========================================================
    // PRUEBA 5: UN NO FIRMANTE NO PUEDE PROPONER
    // =========================================================

    function noFirmanteNoPuedeProponer() public {
        bytes memory datos = _datosAutorizar(
            emisorIng,
            ConstantesUBO.ING
        );

        try intruso.llamar(
            address(multifirma),
            abi.encodeCall(
                IMultifirmaUBO.proponer,
                (address(registro), datos)
            )
        ) {
            Assert.ok(
                false,
                "Un no firmante no debe poder proponer"
            );
        } catch {
            Assert.ok(
                true,
                "La propuesta del intruso debe revertir"
            );
        }

        Assert.ok(
            !registro.estaAutorizado(emisorIng, ConstantesUBO.ING),
            "El intruso no debe autorizar al emisor"
        );
    }

    // =========================================================
    // PRUEBA 6: SOLO LA MULTIFIRMA PUEDE AUTORIZAR
    // =========================================================

    function registroSoloAceptaMultifirma() public {
        try registro.autorizarEmisor(
            emisorIng,
            ConstantesUBO.ING
        ) {
            Assert.ok(
                false,
                "El registro debe rechazar llamadas directas"
            );
        } catch {
            Assert.ok(
                true,
                "La llamada directa debe revertir"
            );
        }

        Assert.ok(
            !registro.estaAutorizado(emisorIng, ConstantesUBO.ING),
            "El emisor debe continuar sin autorizacion"
        );
    }

    // =========================================================
    // PRUEBA 7: REVOCACION Y REAUTORIZACION
    // =========================================================

    function revocacionYReautorizacion() public {
        bytes memory autorizar = _datosAutorizar(
            emisorIng,
            ConstantesUBO.ING
        );

        bytes memory revocar = _datosRevocar(
            emisorIng,
            ConstantesUBO.ING
        );

        // Primera autorizacion.
        _aprobar(autorizar);

        Assert.ok(
            registro.estaAutorizado(emisorIng, ConstantesUBO.ING),
            "Debe estar autorizado inicialmente"
        );

        // Revocacion.
        _aprobar(revocar);

        Assert.ok(
            !registro.estaAutorizado(emisorIng, ConstantesUBO.ING),
            "Debe quedar revocado"
        );

        // Reautorizacion.
        _aprobar(autorizar);

        Assert.ok(
            registro.estaAutorizado(emisorIng, ConstantesUBO.ING),
            "Debe quedar autorizado nuevamente"
        );

        RegistroEmisores.Periodo[] memory historial =
            registro.periodos(emisorIng, ConstantesUBO.ING);

        Assert.equal(
            historial.length,
            uint256(2),
            "Deben existir dos periodos de autorizacion"
        );

        Assert.ok(
            historial[0].hasta != 0,
            "El primer periodo debe estar cerrado"
        );

        Assert.equal(
            uint256(historial[1].hasta),
            uint256(0),
            "El segundo periodo debe estar abierto"
        );
    }

    // =========================================================
    // PRUEBA 8: CONSULTA HISTORICA
    // =========================================================

    function consultaHistoricaEstabaAutorizado() public {
        uint256 t = block.timestamp;

        bytes memory autorizar = _datosAutorizar(
            emisorIng,
            ConstantesUBO.ING
        );

        bytes memory revocar = _datosRevocar(
            emisorIng,
            ConstantesUBO.ING
        );

        // Autorizar: el periodo empieza en el timestamp actual.
        _aprobar(autorizar);

        Assert.ok(
            !registro.estabaAutorizado(
                emisorIng,
                ConstantesUBO.ING,
                t - 1
            ),
            "Antes de la autorizacion debe ser falso"
        );

        Assert.ok(
            registro.estabaAutorizado(
                emisorIng,
                ConstantesUBO.ING,
                t
            ),
            "En el inicio del periodo debe ser verdadero"
        );

        Assert.ok(
            registro.estabaAutorizado(
                emisorIng,
                ConstantesUBO.ING,
                t + 1000
            ),
            "Un periodo abierto incluye momentos posteriores"
        );

        // Revocar: el final del periodo no está incluido.
        _aprobar(revocar);

        RegistroEmisores.Periodo[] memory historial =
            registro.periodos(emisorIng, ConstantesUBO.ING);

        uint256 finPrimerPeriodo = uint256(historial[0].hasta);

        Assert.ok(
            !registro.estabaAutorizado(
                emisorIng,
                ConstantesUBO.ING,
                finPrimerPeriodo
            ),
            "El instante final del periodo no esta incluido"
        );

        if (finPrimerPeriodo > uint256(historial[0].desde)) {
            Assert.ok(
                registro.estabaAutorizado(
                    emisorIng,
                    ConstantesUBO.ING,
                    finPrimerPeriodo - 1
                ),
                "El instante anterior al final debe estar autorizado"
            );
        }

        // Reautorizar: se crea un nuevo periodo.
        _aprobar(autorizar);

        historial = registro.periodos(
            emisorIng,
            ConstantesUBO.ING
        );

        uint256 inicioSegundoPeriodo =
            uint256(historial[1].desde);

        Assert.ok(
            registro.estabaAutorizado(
                emisorIng,
                ConstantesUBO.ING,
                inicioSegundoPeriodo
            ),
            "El nuevo periodo debe incluir su instante inicial"
        );

        Assert.ok(
            registro.estaAutorizado(
                emisorIng,
                ConstantesUBO.ING
            ),
            "Debe estar autorizado actualmente"
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IMultifirmaUBO.sol";

/// @title SimMultifirmaUBO — Simulacro de la multifirma del Módulo A
/// @notice Sirve para ensayar la integración antes de tener la multifirma real.
///         Tiene el MISMO constructor que MultifirmaUBO, así que en integracion.js
///         basta con cambiar el nombre del contrato y la carpeta.
/// @dev    SIMPLIFICACIONES (el módulo real NO puede tenerlas):
///         - Ignora el umbral pedido: basta UNA confirmación para ejecutar.
///         - No valida duplicados ni address(0) en la lista de firmantes.
contract SimMultifirmaUBO is IMultifirmaUBO {
    struct Prop {
        address destino;
        bytes datos;
        uint256 confirmaciones;
        bool ejecutada;
    }

    mapping(address => bool) private _firmante;
    Prop[] private _props;
    mapping(uint256 => mapping(address => bool)) private _confirmo;

    constructor(address[] memory firmantes_, uint256 /* umbral ignorado */) {
        for (uint256 i = 0; i < firmantes_.length; i++) _firmante[firmantes_[i]] = true;
    }

    modifier soloFirmante() {
        require(_firmante[msg.sender], "Sim: no firmante");
        _;
    }

    function proponer(address destino, bytes calldata datos) external soloFirmante returns (uint256 id) {
        id = _props.length;
        _props.push(Prop(destino, datos, 0, false));
        emit Propuesta(id, msg.sender, destino, datos);
    }

    function confirmar(uint256 id) external soloFirmante {
        require(!_confirmo[id][msg.sender], "Sim: ya confirmada");
        _confirmo[id][msg.sender] = true;
        _props[id].confirmaciones += 1;
        emit Confirmacion(id, msg.sender);
    }

    function revocarConfirmacion(uint256 id) external soloFirmante {
        require(_confirmo[id][msg.sender] && !_props[id].ejecutada, "Sim: no revocable");
        _confirmo[id][msg.sender] = false;
        _props[id].confirmaciones -= 1;
        emit ConfirmacionRevocada(id, msg.sender);
    }

    function ejecutar(uint256 id) external soloFirmante {
        Prop storage p = _props[id];
        require(!p.ejecutada && p.confirmaciones >= 1, "Sim: no ejecutable");
        p.ejecutada = true;
        (bool ok, bytes memory ret) = p.destino.call(p.datos);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        emit Ejecucion(id);
    }

    function esFirmante(address cuenta) external view returns (bool) {
        return _firmante[cuenta];
    }

    function umbral() external pure returns (uint256) {
        return 1;
    }

    function numeroConfirmaciones(uint256 id) external view returns (uint256) {
        return _props[id].confirmaciones;
    }
}

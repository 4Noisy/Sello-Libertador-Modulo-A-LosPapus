// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IMultifirmaUBO.sol";

/// @title MultifirmaUBO — PLANTILLA del Módulo A (Curso A)
/// @notice Multifirma m de n de las autoridades de la UBO.
/// @dev    Completar todos los bloques marcados con TODO. No usar bibliotecas externas.
///         Requisitos mínimos:
///         - Constructor: lista de firmantes sin duplicados ni address(0), 1 <= umbral <= n.
///         - Un firmante no puede confirmar dos veces la misma propuesta.
///         - Una propuesta solo se ejecuta una vez y solo con confirmaciones >= umbral.
///         - Si la llamada al destino falla, ejecutar() revierte.
contract MultifirmaUBO is IMultifirmaUBO {
    // ---------------------------------------------------------------
    // Errores personalizados (más baratos en gas que los mensajes de texto)
    // ---------------------------------------------------------------
    error NoEsFirmante(address cuenta);
    error ConfiguracionInvalida();
    error PropuestaInexistente(uint256 id);
    error YaConfirmada(uint256 id, address firmante);
    error NoConfirmada(uint256 id, address firmante);
    error YaEjecutada(uint256 id);
    error ConfirmacionesInsuficientes(uint256 id, uint256 tiene, uint256 necesita);
    error LlamadaFallida(uint256 id);

    struct Propuesta_ {
        address destino;
        bytes datos;
        uint256 confirmaciones;
        bool ejecutada;
    }

    address[] private _firmantes;
    mapping(address => bool) private _esFirmante;
    uint256 private _umbral;
    Propuesta_[] private _propuestas;
    mapping(uint256 => mapping(address => bool)) private _haConfirmado;

    modifier soloFirmante() {
        if (!_esFirmante[msg.sender]) revert NoEsFirmante(msg.sender);
        _;
    }

    modifier existe(uint256 id) {
        if (id >= _propuestas.length) revert PropuestaInexistente(id);
        _;
    }

    constructor(address[] memory firmantes_, uint256 umbral_) {
        // Validar umbral_ (1 <= umbral_ <= firmantes_.length)
        if (umbral_ < 1 || umbral_ > firmantes_.length) revert ConfiguracionInvalida();
        // Recorrer firmantes_, rechazar address(0) y duplicados, y registrarlos
        for (uint256 i = 0; i < firmantes_.length; i++) {
            address f = firmantes_[i];
            if (f == address(0) || _esFirmante[f]) revert ConfiguracionInvalida();
            _esFirmante[f] = true;
            _firmantes.push(f);
        }
        _umbral = umbral_;
    }

    function proponer(address destino, bytes calldata datos)
        external
        override
        soloFirmante
        returns (uint256 id)
    {
        // Guardar la propuesta
        id = _propuestas.length; // el id es el largo ANTES de añadir
        _propuestas.push(Propuesta_(destino, datos, 0, false));
        // TODO: emitir el evento Propuesta (según la interfaz)
    }

    function confirmar(uint256 id) external override soloFirmante existe(id) {
        // Comprobar que no está ejecutada ni confirmada por msg.sender
        Propuesta_ storage p = _propuestas[id]; // storage: el cambio debe persistir
        if (p.ejecutada) revert YaEjecutada(id);
        if (_haConfirmado[id][msg.sender]) revert YaConfirmada(id, msg.sender);
        // Registrar la confirmación
        _haConfirmado[id][msg.sender] = true;
        p.confirmaciones += 1;
        // TODO: emitir el evento Confirmacion (según la interfaz)
    }

    function revocarConfirmacion(uint256 id) external override soloFirmante existe(id) {
        // TODO
        revert("TODO: revocarConfirmacion");
    }

    function ejecutar(uint256 id) external override soloFirmante existe(id) {
        Propuesta_ storage p = _propuestas[id];

        // Comprobar umbral y que no esté ejecutada
        if (p.ejecutada) revert YaEjecutada(id);
        if (p.confirmaciones < _umbral) {
            revert ConfirmacionesInsuficientes(id, p.confirmaciones, _umbral);
        }

        // Marcar como ejecutada ANTES de la llamada externa (patrón CEI).
        // Sirve contra la REENTRADA: si el destino vuelve a llamar a ejecutar(id)
        // durante la llamada, ya la encuentra marcada y revierte.
        p.ejecutada = true;

        // Llamar a destino con datos; si falla, revertir con LlamadaFallida.
        // OJO: al revertir se deshace TODO, también la marca. La propuesta queda
        // pendiente y puede reintentarse; no bloquea a las demás propuestas.
        // (Diseño alternativo, para discutir: no revertir y registrar el fallo.)
        (bool ok, ) = p.destino.call(p.datos);
        if (!ok) revert LlamadaFallida(id);

        // TODO: emitir el evento Ejecucion (según la interfaz)
    }

    function esFirmante(address cuenta) external view override returns (bool) {
        return _esFirmante[cuenta];
    }

    function umbral() external view override returns (uint256) {
        return _umbral;
    }

    function numeroConfirmaciones(uint256 id) external view override existe(id) returns (uint256) {
        return _propuestas[id].confirmaciones;
    }

    /// @notice Lista de firmantes (útil para las pruebas).
    function firmantes() external view returns (address[] memory) {
        return _firmantes;
    }

    // ---------------------------------------------------------------
    // OPCIONAL CON BONIFICACIÓN: rotación de firmantes.
    // Pista: estas funciones solo deben poder llamarse desde la propia
    // multifirma (msg.sender == address(this)), es decir, mediante una propuesta.
    // function reemplazarFirmante(address antiguo, address nuevo) external { ... }
    // ---------------------------------------------------------------
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IRegistroEmisores.sol";
import "../comun/ConstantesUBO.sol";

/// @title RegistroEmisores — PLANTILLA del Módulo A (Curso A)
/// @notice Emisores autorizados por facultad, con historial completo.
/// @dev    Completar los TODO. Requisitos mínimos:
///         - Solo `administracion` (la dirección de MultifirmaUBO) autoriza y revoca.
///         - Solo facultades válidas (ConstantesUBO.esFacultadValida).
///         - Historial de TODOS los periodos: un emisor puede ser autorizado,
///           revocado y vuelto a autorizar; estabaAutorizado() debe acertar
///           para cualquier momento pasado.
///         - Periodos semiabiertos [desde, hasta); hasta = 0 significa abierto.
contract RegistroEmisores is IRegistroEmisores {
    error NoEsAdministracion(address cuenta);
    error FacultadInvalida(bytes32 facultad);
    error DireccionInvalida();
    error YaAutorizado(address emisor, bytes32 facultad);
    error NoAutorizado(address emisor, bytes32 facultad);

    struct Periodo {
        uint64 desde;
        uint64 hasta; // 0 = abierto
    }

    /// @notice Dirección de la multifirma de la UBO.
    address public immutable administracion;

    /// @dev Historial de periodos por emisor y facultad, en orden cronológico.
    mapping(address => mapping(bytes32 => Periodo[])) private _periodos;

    modifier soloAdministracion() {
        if (msg.sender != administracion) revert NoEsAdministracion(msg.sender);
        _;
    }

    constructor(address administracion_) {
        if (administracion_ == address(0)) revert DireccionInvalida();
        administracion = administracion_;
    }

    function autorizarEmisor(address emisor, bytes32 facultad) external override soloAdministracion {
        // Validar emisor != address(0) y facultad válida
        if (emisor == address(0)) revert DireccionInvalida();
        if (!ConstantesUBO.esFacultadValida(facultad)) revert FacultadInvalida(facultad);

        // Revertir con YaAutorizado si hay un periodo abierto
        Periodo[] storage ps = _periodos[emisor][facultad];
        if (ps.length > 0 && ps[ps.length - 1].hasta == 0) {
            revert YaAutorizado(emisor, facultad);
        }

        // Añadir Periodo(desde = block.timestamp, hasta = 0)
        uint64 ahora = uint64(block.timestamp);
        ps.push(Periodo(ahora, 0));
        emit EmisorAutorizado(emisor, facultad, ahora);
    }

    function revocarEmisor(address emisor, bytes32 facultad) external override soloAdministracion {
        // Revertir con NoAutorizado si no hay periodo abierto
        Periodo[] storage ps = _periodos[emisor][facultad];
        if (ps.length == 0 || ps[ps.length - 1].hasta != 0) {
            revert NoAutorizado(emisor, facultad);
        }
        // Cerrar el último periodo (hasta = block.timestamp)
        uint64 ahora = uint64(block.timestamp);
        ps[ps.length - 1].hasta = ahora;
        emit EmisorRevocado(emisor, facultad, ahora);
    }

    function estaAutorizado(address emisor, bytes32 facultad) public view override returns (bool) {
        // ¿El último periodo existe y está abierto?
        Periodo[] storage ps = _periodos[emisor][facultad];
        return ps.length > 0 && ps[ps.length - 1].hasta == 0;
    }

    function estabaAutorizado(address emisor, bytes32 facultad, uint256 momento)
        external
        view
        override
        returns (bool)
    {
        Periodo[] storage ps = _periodos[emisor][facultad];

        // Búsqueda binaria: primer periodo con desde > momento
        uint256 lo = 0;
        uint256 hi = ps.length;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (ps[mid].desde <= momento) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }

        // Ningún periodo había empezado todavía
        if (lo == 0) return false;

        // El candidato es el último periodo con desde <= momento
        Periodo storage p = ps[lo - 1];
        return p.hasta == 0 || momento < p.hasta;
    }

    /// @notice Historial completo (útil para pruebas y auditoría).
    function periodos(address emisor, bytes32 facultad) external view returns (Periodo[] memory) {
        return _periodos[emisor][facultad];
    }
}
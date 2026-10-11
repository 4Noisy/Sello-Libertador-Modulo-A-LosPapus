// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.1.0/utils/cryptography/MerkleProof.sol";
import "../interfaces/IAnclajeLotes.sol";
import "../interfaces/IRegistroEmisores.sol";
import "../comun/ConstantesUBO.sol";

/// @title AnclajeLotes — PLANTILLA del Módulo C (Curso C)
/// @notice MODO ECONÓMICO, alternativo a RegistroTitulos: ancla la raíz de Merkle de una
///         ceremonia completa en UNA transacción, sin guardar cada título en la cadena.
///         No se usa sobre los mismos títulos que ya están en RegistroTitulos: es otra
///         forma de emitir, más barata y con menos funciones (no hay estado por título).
/// @dev    Completar los TODO. Requisitos mínimos:
///         - Solo emisores autorizados AHORA en la facultad.
///         - Rechazar raíz vacía y raíces repetidas.
///         - Hoja = ConstantesUBO.hojaLote(localizador, compromiso).
///         - Verificación con MerkleProof.verify (pares ordenados).
contract AnclajeLotes is IAnclajeLotes {
    error NoAutorizado(address cuenta, bytes32 facultad);
    error RaizInvalida();
    error RaizDuplicada(bytes32 raiz);
    error LoteInexistente(uint256 loteId);

    struct Lote {
        bytes32 raiz;
        bytes32 facultad;
        bytes32 idCeremonia;
        address emisor;
        uint64 fecha;
    }

    IRegistroEmisores public immutable registro;
    mapping(uint256 => Lote) private _lotes;
    mapping(bytes32 => bool) private _raizUsada;
    uint256 private _siguienteId = 1;

    constructor(address registro_) {
        registro = IRegistroEmisores(registro_);
    }

    function anclarLote(bytes32 raiz, bytes32 facultad, bytes32 idCeremonia)
        external
        override
        returns (uint256 loteId)
    {
        // TODO: autorización, validaciones, guardar el lote y emitir LoteAnclado
        raiz; facultad; idCeremonia; loteId;
        revert("TODO: anclarLote");
    }

    function verificarInclusion(
        uint256 loteId,
        bytes10 localizador,
        bytes32 compromiso,
        bytes32[] calldata prueba
    ) external view override returns (bool) {
        // TODO: revertir con LoteInexistente si no existe
        // TODO: calcular la hoja y verificar con MerkleProof.verifyCalldata
        loteId; localizador; compromiso; prueba;
        revert("TODO: verificarInclusion");
    }

    function obtenerLote(uint256 loteId) external view returns (Lote memory) {
        return _lotes[loteId];
    }
}

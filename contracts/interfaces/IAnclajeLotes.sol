// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IAnclajeLotes — Interfaz del Módulo C (Curso C)
/// @notice MODO ECONÓMICO de emisión, alternativo a IRegistroTitulos: registra la raíz de
///         Merkle de todos los títulos de una ceremonia en una sola transacción.
///         Los títulos anclados así NO se registran además uno a uno.
/// @dev    NO MODIFICAR sin acuerdo de los tres cursos.
///         Definición OBLIGATORIA de la hoja (doble hash, como recomienda OpenZeppelin):
///             hoja = keccak256(bytes.concat(keccak256(abi.encode(localizador, compromiso))))
///         El árbol se construye con pares ORDENADOS (menor primero), compatible
///         con MerkleProof de OpenZeppelin.
interface IAnclajeLotes {
    event LoteAnclado(
        uint256 indexed loteId,
        bytes32 indexed facultad,
        bytes32 raiz,
        bytes32 idCeremonia,
        address emisor
    );

    /// @notice Ancla una raíz. Solo un emisor autorizado AHORA en `facultad`.
    /// @dev Los loteId empiezan en 1. Debe revertir si raiz = bytes32(0) o si
    ///      la misma raíz ya fue anclada.
    function anclarLote(bytes32 raiz, bytes32 facultad, bytes32 idCeremonia)
        external
        returns (uint256 loteId);

    /// @notice ¿Está (localizador, compromiso) incluido en el lote `loteId`?
    function verificarInclusion(
        uint256 loteId,
        bytes10 localizador,
        bytes32 compromiso,
        bytes32[] calldata prueba
    ) external view returns (bool);
}

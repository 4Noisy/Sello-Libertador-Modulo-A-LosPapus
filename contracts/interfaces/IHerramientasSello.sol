// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IHerramientasSello — Interfaz del Módulo C (Curso C)
/// @notice Cálculos auxiliares del sistema, escritos en Solidity como funciones `pure`:
///         no leen ni escriben estado y se pueden llamar gratis desde Remix.
///         Sustituyen a lo que antes se pedía programar en JavaScript.
/// @dev    NO MODIFICAR sin acuerdo de los tres cursos.
interface IHerramientasSello {
    /// @notice ¿Sirve este byte para elegir un símbolo sin sesgo?
    /// @dev El alfabeto tiene 36 símbolos y un byte toma 256 valores. Solo se aceptan
    ///      los bytes que se reparten de forma pareja entre los 36 símbolos.
    function byteAceptado(uint8 b) external pure returns (bool);

    /// @notice Símbolo del alfabeto "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" que
    ///         corresponde a un byte ACEPTADO. Debe revertir si el byte no es aceptado.
    function simboloDe(uint8 b) external pure returns (bytes1);

    /// @notice Deriva un localizador válido (10 símbolos del alfabeto) a partir de una
    ///         semilla aleatoria de 32 bytes, sin sesgo de módulo.
    /// @dev Determinista: la misma semilla produce siempre el mismo localizador.
    ///      Fuente de bytes: h = keccak256(abi.encode(semilla)); se recorren sus 32 bytes
    ///      en orden; los no aceptados se descartan; si se agotan, h = keccak256(abi.encode(h)).
    function derivarLocalizador(bytes32 semilla) external pure returns (bytes10);

    /// @notice Raíz de Merkle de una lista de hojas, compatible con MerkleProof de OpenZeppelin.
    /// @dev Pares ORDENADOS (el menor primero) y keccak256(abi.encodePacked(a, b)).
    ///      Si un nivel tiene un número impar de nodos, el último sube sin emparejar.
    ///      Debe revertir si la lista está vacía.
    function raizDeMerkle(bytes32[] calldata hojas) external pure returns (bytes32);

    /// @notice keccak256 del texto del documento (ya canonicalizado).
    function hashDocumento(string calldata documentoCanonico) external pure returns (bytes32);

    /// @notice Compromiso = keccak256(abi.encode(sal, hashDocumento)).
    function compromiso(bytes32 sal, bytes32 hashDoc) external pure returns (bytes32);

    /// @notice Hoja del árbol de una ceremonia (doble hash).
    function hojaLote(bytes10 localizador, bytes32 compromiso_) external pure returns (bytes32);
}

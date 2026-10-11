// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IHerramientasSello.sol";
import "../comun/ConstantesUBO.sol";

/// @title HerramientasSello — PLANTILLA del Módulo C (Curso C)
/// @notice Cálculos auxiliares en Solidity. Todas las funciones son `pure`: se pueden
///         llamar gratis desde «Deploy & Run» de Remix, sin enviar transacciones.
/// @dev    Completar los TODO. Las tres últimas funciones ya están hechas.
contract HerramientasSello is IHerramientasSello {
    error ByteNoAceptado(uint8 b);
    error ListaVacia();

    /// @dev Los 36 símbolos permitidos, en orden. ALFABETO[i] devuelve el símbolo número i.
    bytes internal constant ALFABETO = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    // ---------------------------------------------------------------
    // Localizador sin sesgo de módulo
    // ---------------------------------------------------------------
    function byteAceptado(uint8 b) public pure override returns (bool) {
        // TODO: ¿cuál es el mayor múltiplo de 36 que cabe en 256?
        //       Se aceptan los bytes menores que ese valor.
        b;
        return false;
    }

    function simboloDe(uint8 b) public pure override returns (bytes1) {
        // TODO: revertir con ByteNoAceptado si el byte no es aceptado
        // TODO: devolver el símbolo que corresponde al resto de dividir b por 36
        b;
        revert("TODO: simboloDe");
    }

    function derivarLocalizador(bytes32 semilla) external pure override returns (bytes10) {
        // TODO: seguir el procedimiento descrito en la interfaz:
        //   1. h = keccak256(abi.encode(semilla))
        //   2. recorrer los 32 bytes de h en orden: uint8(h[i])
        //   3. si el byte es aceptado, añadir su símbolo; si no, descartarlo
        //   4. si se acaban los 32 bytes y faltan símbolos: h = keccak256(abi.encode(h))
        //   5. al tener 10 símbolos, devolverlos como bytes10
        // PISTA: construye el resultado en un `bytes memory` de largo 10 y conviértelo
        //        al final con bytes10(...).
        semilla;
        revert("TODO: derivarLocalizador");
    }

    // ---------------------------------------------------------------
    // Raíz de Merkle
    // ---------------------------------------------------------------
    function raizDeMerkle(bytes32[] calldata hojas) external pure override returns (bytes32) {
        // TODO: revertir con ListaVacia si no hay hojas
        // TODO: copiar las hojas a memoria y reducir nivel a nivel:
        //       - emparejar (0,1), (2,3), ... con _hashPar
        //       - si sobra un nodo, sube tal cual al nivel siguiente
        //       - repetir hasta que quede un solo nodo: la raíz
        hojas;
        revert("TODO: raizDeMerkle");
    }

    /// @dev Hash de un par ordenado, igual que MerkleProof de OpenZeppelin. YA HECHA.
    function _hashPar(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // ---------------------------------------------------------------
    // Funciones YA HECHAS (no modificar)
    // ---------------------------------------------------------------
    function hashDocumento(string calldata documentoCanonico) external pure override returns (bytes32) {
        return keccak256(bytes(documentoCanonico));
    }

    function compromiso(bytes32 sal, bytes32 hashDoc) external pure override returns (bytes32) {
        return ConstantesUBO.compromiso(sal, hashDoc);
    }

    function hojaLote(bytes10 localizador, bytes32 compromiso_) external pure override returns (bytes32) {
        return ConstantesUBO.hojaLote(localizador, compromiso_);
    }
}

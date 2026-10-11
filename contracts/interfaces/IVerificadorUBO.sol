// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IVerificadorUBO — Interfaz del Módulo C (Curso C)
/// @notice Emite el veredicto sobre un título a partir de su localizador y del
///         compromiso que el verificador recalcula con el documento recibido.
///         Nadie necesita billetera: es una función de solo lectura.
/// @dev    NO MODIFICAR sin acuerdo de los tres cursos.
interface IVerificadorUBO {
    enum Veredicto {
        Valido,             // 0
        Revocado,           // 1 (incluye los títulos rectificados)
        Suspendido,         // 2
        Inexistente,        // 3
        EmisorNoAutorizado, // 4: el emisor no estaba autorizado en la fecha de emisión
        DocumentoAlterado   // 5: el compromiso recalculado no coincide
    }

    /// @notice Verifica un título.
    /// @dev Orden OBLIGATORIO de comprobación (el primero que falla decide):
    ///      1) Inexistente  2) EmisorNoAutorizado  3) Revocado
    ///      4) Suspendido   5) DocumentoAlterado   6) Valido
    function verificar(bytes10 localizador, bytes32 compromisoRecalculado)
        external
        view
        returns (Veredicto);
}

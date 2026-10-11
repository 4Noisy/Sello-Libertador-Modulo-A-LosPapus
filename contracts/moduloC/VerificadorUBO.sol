// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IVerificadorUBO.sol";
import "../interfaces/IRegistroTitulos.sol";
import "../interfaces/IRegistroEmisores.sol";

/// @title VerificadorUBO — PLANTILLA del Módulo C (Curso C)
/// @notice Aplica la regla RN-06 y devuelve un veredicto.
/// @dev    Completar los TODO. Orden OBLIGATORIO (el primero que falla decide):
///         1) Inexistente  2) EmisorNoAutorizado (en la FECHA DE EMISIÓN)
///         3) Revocado     4) Suspendido   5) DocumentoAlterado   6) Valido
contract VerificadorUBO is IVerificadorUBO {
    IRegistroTitulos public immutable titulos;
    IRegistroEmisores public immutable registro;

    constructor(address titulos_, address registro_) {
        titulos = IRegistroTitulos(titulos_);
        registro = IRegistroEmisores(registro_);
    }

    function verificar(bytes10 localizador, bytes32 compromisoRecalculado)
        external
        view
        override
        returns (Veredicto)
    {
        // TODO: obtener el título con titulos.obtenerTitulo(localizador)
        // TODO: aplicar las seis comprobaciones en el orden obligatorio
        localizador; compromisoRecalculado;
        revert("TODO: verificar");
    }

    /// @notice Versión explicativa para el verificador humano.
    /// @dev    OBLIGATORIA: devuelve el veredicto y un texto claro en español
    ///         para un empleador, p. ej. "Titulo valido emitido por la UBO".
    ///         Si el título fue rectificado, la explicación debe indicar el nuevo localizador
    ///         (campo rectificadoComo) para que el empleador pida el documento correcto.
    function verificarConExplicacion(bytes10 localizador, bytes32 compromisoRecalculado)
        external
        view
        returns (Veredicto veredicto, string memory explicacion)
    {
        // TODO
        localizador; compromisoRecalculado; veredicto; explicacion;
        revert("TODO: verificarConExplicacion");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IMultifirmaUBO — Interfaz del Módulo A (Curso A)
/// @notice Multifirma m de n de las autoridades de la UBO. Es la única cuenta
///         con permiso para autorizar y revocar emisores en RegistroEmisores.
/// @dev    NO MODIFICAR sin acuerdo de los tres cursos.
interface IMultifirmaUBO {
    event Propuesta(uint256 indexed id, address indexed proponente, address destino, bytes datos);
    event Confirmacion(uint256 indexed id, address indexed firmante);
    event ConfirmacionRevocada(uint256 indexed id, address indexed firmante);
    event Ejecucion(uint256 indexed id);

    /// @notice Propone una llamada a `destino` con `datos` (calldata codificado).
    ///         Solo firmantes. La propuesta NO cuenta como confirmación automática.
    /// @return id Identificador de la propuesta (empieza en 0).
    function proponer(address destino, bytes calldata datos) external returns (uint256 id);

    /// @notice Confirma una propuesta. Solo firmantes; una vez por firmante.
    function confirmar(uint256 id) external;

    /// @notice Retira la propia confirmación antes de que se ejecute.
    function revocarConfirmacion(uint256 id) external;

    /// @notice Ejecuta la propuesta si tiene al menos `umbral()` confirmaciones.
    ///         Solo firmantes; una única vez. Revierte si la llamada falla.
    function ejecutar(uint256 id) external;

    function esFirmante(address cuenta) external view returns (bool);
    function umbral() external view returns (uint256);
    function numeroConfirmaciones(uint256 id) external view returns (uint256);
}

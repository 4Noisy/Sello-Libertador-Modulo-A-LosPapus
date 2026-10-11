// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IRegistroTitulos.sol";
import "../interfaces/IRegistroEmisores.sol";
import "../comun/ConstantesUBO.sol";

/// @title RegistroTitulos — PLANTILLA del Módulo B (Curso B)
/// @notice Registro de títulos por localizador, sin billetera del titulado.
/// @dev    Completar los TODO. Requisitos mínimos:
///         - Solo emisores autorizados AHORA en la facultad (consulta al registro del Módulo A).
///         - Localizador válido: 10 caracteres en [0-9A-Z]; único para siempre.
///         - emitirLote: todo o nada; largos iguales; 1 <= n <= ConstantesUBO.MAX_LOTE;
///           detectar localizadores repetidos DENTRO del mismo lote.
///         - Cambios de estado solo por emisores de la MISMA facultad del título.
///         - Transiciones válidas:
///             Emitido -> Suspendido -> Emitido   (suspender / reactivar)
///             Emitido | Suspendido -> Revocado   (revocar o rectificar; definitivo)
///         - Usar errores personalizados (no cadenas de texto) y eventos de la interfaz.
///         - Pausa de emergencia («circuit breaker»): solo `administracion` (la multifirma
///           del Módulo A) puede pausar y reanudar. REGLA: en pausa se bloquea toda función
///           que CREA un título (emitir, emitirLote y rectificar, que crea el título nuevo).
///           Las que solo INVALIDAN (suspender, revocar) siguen permitidas. El modificador
///           se aplica a la función externa completa: rectificar queda bloqueada entera,
///           aunque por dentro revoque. En pausa, un título erróneo se revoca con revocar()
///           y se rectifica después de reanudar.
contract RegistroTitulos is IRegistroTitulos {
    error NoAutorizado(address cuenta, bytes32 facultad);
    error LocalizadorInvalido(bytes10 localizador);
    error LocalizadorExistente(bytes10 localizador);
    error CompromisoVacio();
    error LoteInvalido(uint256 largoLocalizadores, uint256 largoCompromisos);
    error TituloInexistente(bytes10 localizador);
    error TransicionInvalida(bytes10 localizador, Estado actual);
    error NoEsAdministracion(address cuenta);
    error EnPausa();

    event Pausado(address por);
    event Reanudado(address por);

    IRegistroEmisores public immutable registroEmisores;
    address public immutable administracion;
    bool public pausado;

    mapping(bytes10 => Titulo) private _titulos;

    /// @notice Número total de títulos registrados (útil para estadísticas y pruebas).
    uint256 public totalTitulos;

    constructor(address registroEmisores_, address administracion_) {
        registroEmisores = IRegistroEmisores(registroEmisores_);
        administracion = administracion_;
    }

    modifier soloAdministracion() {
        if (msg.sender != administracion) revert NoEsAdministracion(msg.sender);
        _;
    }

    modifier cuandoNoPausado() {
        // TODO: revertir con EnPausa() si pausado
        _;
    }

    // ---------------------------------------------------------------
    // Pausa de emergencia
    // ---------------------------------------------------------------
    function pausar() external soloAdministracion {
        // TODO: pausado = true; emitir Pausado
        revert("TODO: pausar");
    }

    function reanudar() external soloAdministracion {
        // TODO
        revert("TODO: reanudar");
    }

    // ---------------------------------------------------------------
    // Emisión
    // ---------------------------------------------------------------
    function emitir(bytes10 localizador, bytes32 facultad, bytes32 codigoPrograma, bytes32 compromiso)
        external
        override
        cuandoNoPausado
    {
        // TODO: comprobar la autorización del emisor en la facultad
        // TODO: llamar a _registrar(...)
        localizador; facultad; codigoPrograma; compromiso;
        revert("TODO: emitir");
    }

    function emitirLote(
        bytes10[] calldata localizadores,
        bytes32 facultad,
        bytes32 codigoPrograma,
        bytes32[] calldata compromisos
    ) external override cuandoNoPausado {
        // TODO: validar largos y MAX_LOTE (LoteInvalido)
        // TODO: comprobar la autorización UNA sola vez (ahorro de gas)
        // TODO: registrar cada título; si uno falla, toda la transacción revierte
        // PREGUNTA DE SEGURIDAD: ¿qué pasa si el mismo localizador aparece dos veces en el lote?
        localizadores; facultad; codigoPrograma; compromisos;
        revert("TODO: emitirLote");
    }

    // ---------------------------------------------------------------
    // Ciclo de vida
    // ---------------------------------------------------------------
    function suspender(bytes10 localizador, uint8 motivo) external override {
        // TODO
        localizador; motivo;
        revert("TODO: suspender");
    }

    function reactivar(bytes10 localizador) external override {
        // TODO
        localizador;
        revert("TODO: reactivar");
    }

    function revocar(bytes10 localizador, uint8 motivo) external override {
        // TODO
        localizador; motivo;
        revert("TODO: revocar");
    }

    function rectificar(bytes10 anterior, bytes10 nuevo, bytes32 nuevoCompromiso)
        external
        override
        cuandoNoPausado
    {
        // TODO: `anterior` debe estar Emitido o Suspendido y el emisor, autorizado en su facultad
        // TODO: revocarlo con MOTIVO_RECTIFICACION, registrar `nuevo` con la misma facultad
        //       y programa, enlazar rectificadoComo y emitir TituloRectificado
        anterior; nuevo; nuevoCompromiso;
        revert("TODO: rectificar");
    }

    function obtenerTitulo(bytes10 localizador) external view override returns (Titulo memory) {
        return _titulos[localizador]; // inexistente => estado Inexistente
    }

    // ---------------------------------------------------------------
    // Funciones internas sugeridas
    // ---------------------------------------------------------------
    /// @dev Valida y guarda un título; emite TituloEmitido.
    function _registrar(bytes10 localizador, bytes32 facultad, bytes32 codigoPrograma, bytes32 compromiso)
        internal
    {
        // TODO: _localizadorValido, que no exista, compromiso != 0, guardar, totalTitulos++, evento
        localizador; facultad; codigoPrograma; compromiso;
        revert("TODO: _registrar");
    }

    /// @dev ¿Son los 10 bytes caracteres ASCII '0'-'9' o 'A'-'Z'?
    ///      Pista: bytes1 b = localizador[i];  (b >= "0" && b <= "9") || (b >= "A" && b <= "Z")
    function _localizadorValido(bytes10 localizador) internal pure returns (bool) {
        // TODO
        localizador;
        return false;
    }
}

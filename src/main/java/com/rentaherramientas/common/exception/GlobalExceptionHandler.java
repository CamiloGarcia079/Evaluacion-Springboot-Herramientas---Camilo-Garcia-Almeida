package com.rentaherramientas.common.exception;

import com.rentaherramientas.common.dto.ApiResponseDto;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Traduce las excepciones de toda la API a respuestas JSON con el mismo formato.
 *
 * Es un unico manejador para todos los modulos. Asi un acceso denegado responde
 * 403 y una ruta inexistente 404 sin importar el modulo, en vez de caer en el
 * caso generico y salir como error 500.
 *
 * | Codigo | Cuando                                                   |
 * |--------|----------------------------------------------------------|
 * | 400    | Validacion, JSON mal formado, parametro faltante o de tipo invalido |
 * | 401    | Credenciales invalidas o sin autenticar                  |
 * | 403    | Autenticado, pero el rol no alcanza                      |
 * | 404    | El recurso no existe                                     |
 * | 405    | Metodo HTTP no permitido en esa ruta                     |
 * | 409    | Violacion de una restriccion de la base de datos         |
 * | 422    | Regla de negocio incumplida                              |
 * | 500    | Error inesperado                                         |
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(BusinessRuleException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleBusinessRuleException(BusinessRuleException ex) {
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY)
                .body(ApiResponseDto.error(ex.getMessage()));
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleResourceNotFoundException(ResourceNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ApiResponseDto.error(ex.getMessage()));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleIllegalArgumentException(IllegalArgumentException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponseDto.error(ex.getMessage()));
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleIllegalStateException(IllegalStateException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(ApiResponseDto.error(ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponseDto<Map<String, String>>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, String> errores = new LinkedHashMap<>();
        ex.getBindingResult().getAllErrors().forEach(error -> {
            String campo = (error instanceof FieldError fe) ? fe.getField() : error.getObjectName();
            errores.putIfAbsent(campo, error.getDefaultMessage());
        });

        ApiResponseDto<Map<String, String>> respuesta = ApiResponseDto.<Map<String, String>>builder()
                .success(false)
                .message("Error de validación en los campos enviados")
                .data(errores)
                .build();
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(respuesta);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleJsonInvalido(HttpMessageNotReadableException ex) {
        log.debug("JSON mal formado: {}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponseDto.error("El cuerpo de la petición no es un JSON válido, está vacío o tiene un valor no permitido"));
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleTipoInvalido(MethodArgumentTypeMismatchException ex) {
        String esperado = ex.getRequiredType() == null ? "otro tipo" : ex.getRequiredType().getSimpleName();
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponseDto.error("El parámetro '" + ex.getName() + "' no es válido. Se esperaba " + esperado + "."));
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleParametroFaltante(MissingServletRequestParameterException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponseDto.error("Falta el parámetro obligatorio '" + ex.getParameterName() + "'"));
    }

    @ExceptionHandler({BadCredentialsException.class, UsernameNotFoundException.class})
    public ResponseEntity<ApiResponseDto<Void>> handleCredenciales(RuntimeException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(ApiResponseDto.error("Credenciales inválidas"));
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleNoAutenticado(AuthenticationException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(ApiResponseDto.error("No autenticado: debe iniciar sesión y enviar el token"));
    }

    /** El recurso existe pero pertenece a otro usuario (tercer nivel de autorizacion). */
    @ExceptionHandler(AccesoDenegadoException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleAccesoDenegadoNegocio(AccesoDenegadoException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(ApiResponseDto.error(ex.getMessage()));
    }

    /** Lo lanza @PreAuthorize cuando el rol no alcanza. Sin este metodo saldria como 500. */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleAccesoDenegado(AccessDeniedException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(ApiResponseDto.error("Acceso denegado: su rol no tiene permiso para realizar esta operación"));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleMetodoNoSoportado(HttpRequestMethodNotSupportedException ex) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED)
                .body(ApiResponseDto.error("El método " + ex.getMethod() + " no está permitido en esta ruta"));
    }

    /** Spring 6.1+ lanza esta excepcion para rutas que no existen. */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleRutaInexistente(NoResourceFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ApiResponseDto.error("La ruta solicitada no existe: /" + ex.getResourcePath()));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiResponseDto<Void>> handleIntegridad(DataIntegrityViolationException ex) {
        log.warn("Violación de integridad en base de datos: {}", ex.getMostSpecificCause().getMessage());
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(ApiResponseDto.error("La operación viola una restricción de la base de datos: "
                        + "un dato único ya existe o una referencia no es válida."));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponseDto<Void>> handleGeneralException(Exception ex) {
        log.error("Error no controlado", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponseDto.error("Ocurrió un error interno en el servidor: " + ex.getMessage()));
    }
}

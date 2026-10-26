# Evidencias del examen: devolución y reporte de daños

Endpoint: `POST /api/v1/reservas/{id}/registrar-devolucion` (rol proveedor).

| Archivo | Qué muestra |
|---|---|
| `1_swagger_registrar_devolucion.png` | Petición a `/reservas/31/registrar-devolucion` con el cuerpo `{"estado":"DANOS", ...}` hecha desde Swagger |
| `2_y_3_base_de_datos_reserva_y_reporte_dano.png` | La reserva 31 en `FINALIZADA` con `estado_devolucion = DEVUELTO_CON_DANOS`, y el nuevo registro en la tabla `reporte_dano` |

La respuesta que se ve en la primera captura es un 422 porque corresponde a un segundo intento sobre la misma reserva, que ya había sido devuelta (una devolución no se puede registrar dos veces). La primera llamada, la que creó el registro, es la que se confirma en la base de datos.

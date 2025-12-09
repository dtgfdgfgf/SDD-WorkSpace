using DuotifyMembership.Core.Exceptions;
using System.Net;
using System.Text.Json;

namespace DuotifyMembership.Api.Middleware;

public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        _logger.LogError(exception, "An unhandled exception occurred");

        var (statusCode, errorCode, message) = exception switch
        {
            DuplicateIdNumberException => (HttpStatusCode.Conflict, "DUPLICATE_ID_NUMBER", exception.Message),
            DuplicateEmailException => (HttpStatusCode.Conflict, "DUPLICATE_EMAIL", exception.Message),
            VerificationCodeExpiredException => (HttpStatusCode.BadRequest, "CODE_EXPIRED", exception.Message),
            VerificationCodeInvalidException => (HttpStatusCode.BadRequest, "CODE_INVALID", exception.Message),
            _ => (HttpStatusCode.InternalServerError, "INTERNAL_ERROR", "An unexpected error occurred")
        };

        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)statusCode;

        var response = new
        {
            ErrorCode = errorCode,
            Message = message,
            Timestamp = DateTime.UtcNow
        };

        await context.Response.WriteAsync(JsonSerializer.Serialize(response, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        }));
    }
}

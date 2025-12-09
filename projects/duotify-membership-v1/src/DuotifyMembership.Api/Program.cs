using DuotifyMembership.Api.Middleware;
using DuotifyMembership.Core.Interfaces;
using DuotifyMembership.Core.Services;
using DuotifyMembership.Infrastructure.Data;
using DuotifyMembership.Infrastructure.Repositories;
using DuotifyMembership.Infrastructure.Services;
using DuotifyMembership.Jobs;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Database
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Memory Cache (Constitution IV alternative)
builder.Services.AddMemoryCache();

// Repositories
builder.Services.AddScoped<IMemberRepository, MemberRepository>();
builder.Services.AddScoped<IVerificationCodeRepository, VerificationCodeRepository>();

// Services
builder.Services.AddScoped<IMemberService, MemberService>();
builder.Services.AddScoped<IVerificationService, VerificationService>();
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<ICaptchaValidator, CaptchaValidator>();

// Background Jobs
builder.Services.AddHostedService<CleanupUnverifiedMembersJob>();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseMiddleware<ExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();

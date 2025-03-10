# Stage 1: Build the application
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["SimpleReact.API.csproj", "./"]
RUN dotnet restore

# Copy the rest of the code
COPY . .

# Build the application
RUN dotnet build "SimpleReact.API.csproj" -c Release -o /app/build

# Stage 2: Publish the application
FROM build AS publish
RUN dotnet publish "SimpleReact.API.csproj" -c Release -o /app/publish

# Stage 3: Create the runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production

# Expose port 5000
EXPOSE 5000

# Set the entry point
ENTRYPOINT ["dotnet", "SimpleReact.API.dll"]

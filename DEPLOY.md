# Deployment Guide — BeautyConnect MVP

## 🚀 Deploy Automático via GitHub Pages (Recomendado)

Apenas **3 passos**:

### 1. Criar repositório no GitHub
```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/beautyconnect.git
git push -u origin main
```

### 2. Ativar GitHub Pages no repositório
- Vá para **Settings** → **Pages**
- Em "Build and deployment", selecione:
  - Source: **GitHub Actions**
  - (O workflow já está configurado em `.github/workflows/build_web.yml`)

### 3. Clicar em "Deploy"
- Na aba **Actions**, clique no workflow que está rodando
- Após ~2 minutos, o build completa automaticamente
- Seu app estará em: `https://seu-usuario.github.io/beautyconnect/`

## ✅ O que acontece automaticamente

A cada `git push` para `main`:
1. GitHub Actions dispara o workflow
2. Flutter compila o projeto com `flutter build web --release`
3. Arquivos em `build/web/` são publicados em GitHub Pages
4. Link atualizado em ~2 minutos

## 🔗 Link final
```
https://seu-usuario.github.io/beautyconnect/
```

---

## Alternativa: Build Local (Se preferir compilar na sua máquina)

```bash
flutter pub get
flutter build web --release
# Arquivos prontos em: build/web/
```

Hospede a pasta `build/web/` em qualquer serviço (Netlify, Vercel, Firebase Hosting, etc).

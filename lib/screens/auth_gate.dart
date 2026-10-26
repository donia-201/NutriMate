import 'package:firebase_auth/firebase_auth.dart'hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:nutrimate/screens/home_page.dart';

import '../core/app_theme.dart';

import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';

import '../core/app_widgets.dart';
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context){

  return StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder:(context, snapshot){
    if( snapshot.hasError){
      return Scaffold(
        body:SafeArea(
          child: Center(
            child:Text('Small choices. Lasting nourishment.',
                style: AppTheme.subTitle),
          ),
        )
      );}
    if(snapshot.connectionState == ConnectionState.waiting){
      return Scaffold(
        body:SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        )
      );
    }
    if(snapshot.hasData==false){


      return Theme(
          data: AppTheme.authTheme(Theme.of(context)),
          child: SignInScreen(

        providers: [EmailAuthProvider(),

        ],

        oauthButtonVariant: OAuthButtonVariant.icon,

        subtitleBuilder: (context, authAction) {
          final isSignIn = authAction == AuthAction.signIn;

          return Padding(
            padding: const EdgeInsets.only( bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSignIn ? 'Welcome back' : 'Create your account',
                  style: AppTheme.titleBold,
                ),
                const SizedBox(height: 4),
                Text(
                  'Small choices. Lasting nourishment.',
                  style: AppTheme.subTitle,
                ),
              ],
            ),
          );
        },

        footerBuilder: (context, _) => Column(
          children: [
            const Text(
              'or continue with',
              textAlign: TextAlign.center,
              style: AppTheme.subTitle,
            ),
            const SizedBox(height: 16),
            SizedBox(
              child: OAuthProviderButton(
                provider: GoogleProvider(
                  clientId: "991335309583-34a8k9985majjtmjp5fqged6jcrojdv4.apps.googleusercontent.com",
                ),
                variant: OAuthButtonVariant.icon,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Continue as Guest',
              outlined: true,
              onPressed: () => FirebaseAuth.instance.signInAnonymously(),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can explore recipes as a guest, but favorites and synced data require an account.',
              textAlign: TextAlign.center,
              style: AppTheme.small,
            ),
          ],
        ),
          ),

      );

    }
    return const HomePage();
    }

  );
}
}
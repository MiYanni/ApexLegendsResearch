global function OnWeaponChargeBegin_ability_mirage_ultimate
global function OnWeaponChargeEnd_ability_mirage_ultimate
global function OnWeaponAttemptOffhandSwitch_ability_mirage_ultimate

bool function OnWeaponAttemptOffhandSwitch_ability_mirage_ultimate( entity weapon )
{
	entity player = weapon.GetWeaponOwner()
	if ( player.IsPhaseShifted() )
		return false

	if ( !PlayerCanUseDecoy( player ) )
		return false

	return true
}

var function OnWeaponPrimaryAttack_mirage_ultimate( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	var ammoToReturn = OnWeaponPrimaryAttack_holopilot( weapon, attackParams )
	#if SERVER
	float fireDuration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
	thread HolsterAndDisableWeaponsMirageUltimate( weapon.GetWeaponOwner(), fireDuration )
	#endif
	return ammoToReturn
}

void function OnWeaponChargeEnd_ability_mirage_ultimate( entity weapon )
{
	if ( weapon.GetWeaponPrimaryClipCount() == 0 ) //This is to prevent a bad bug where ChargeEnd is being called 3 times on the server. Investigating that.
		return

	weapon.SetWeaponPrimaryClipCount( 0 )
	WeaponPrimaryAttackParams attackParams
	OnWeaponPrimaryAttack_mirage_ultimate( weapon, attackParams )
}

#if SERVER
void function HolsterAndDisableWeaponsMirageUltimate( entity ownerPlayer, float fireDuration )
{
	ownerPlayer.EndSignal( "OnDestroy" )
	ownerPlayer.EndSignal( "OnDeath" )
	ownerPlayer.EndSignal( "OnSyncedMelee" )
	ownerPlayer.EndSignal( "BleedOut_OnStartDying" )

	HolsterAndDisableWeapons( ownerPlayer )

	OnThreadEnd(
	function() : ( ownerPlayer )
		{
			if ( IsValid( ownerPlayer ) )
			{
				DeployAndEnableWeapons( ownerPlayer )
			}
		}
	)

	wait fireDuration
}

void function MirageUltCloakThink( entity ownerPlayer, float fireDuration, float flickerDuration )
{
	ownerPlayer.EndSignal( "OnDestroy" )
	ownerPlayer.EndSignal( "OnDeath" )
	ownerPlayer.EndSignal( "OnSyncedMelee" )
	ownerPlayer.EndSignal( "BleedOut_OnStartDying" )

	EnableCloak( ownerPlayer, fireDuration )
	ownerPlayer.SetCloakFlicker( 0.5, flickerDuration )

	int statusId = 	StatusEffect_AddTimed( ownerPlayer, eStatusEffect.speed_boost, 0.15, fireDuration, 0.5 )
	OnThreadEnd(
	function() : ( ownerPlayer, statusId )
		{
			if ( IsValid( ownerPlayer ) )
			{
				if ( IsCloaked( ownerPlayer ) )
					DisableCloak( ownerPlayer, 0.0 )
				ownerPlayer.SetCloakFlicker( 0.5, 0 )
				StatusEffect_Stop( ownerPlayer, statusId )
			}
		}
	)

	wait fireDuration
}
#endif

bool function OnWeaponChargeBegin_ability_mirage_ultimate( entity weapon )
{
	weapon.EmitWeaponSound_1p3p( "Mirage_Vanish_Activate_1P", "Mirage_Vanish_Activate_3P" )
	entity ownerPlayer = weapon.GetWeaponOwner()
	PlayerUsedOffhand( ownerPlayer, weapon, false )
	#if SERVER
	PlayBattleChatterLineToSpeakerAndTeam( ownerPlayer, "bc_super" )
	float fireDuration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration ) + weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
	float flickerDuration = 0.25//weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
	thread MirageUltCloakThink( ownerPlayer, fireDuration, flickerDuration )
	#endif
	return true
}
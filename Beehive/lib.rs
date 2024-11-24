use anchor_lang::prelude::*;

declare_id!("4JnqmqsP4Zbk86wz1seR8QjP28jZydwCawvmZfMC9zMc");

// Will be a owner address
const OWNER: &str = "6E64N2BR2ZHKvALAj1DCjVu4ocU2egv52H7wetZaa7c";

#[program]
pub mod beehive {
    use std::str::FromStr;

    use anchor_lang::solana_program::{system_instruction};

    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let state = &mut ctx.accounts.state;
        // set the default state of paused is false
        state.is_paused = false;

        Ok(())
    }

    pub fn pause(ctx: Context<TogglePause>) -> Result<()> {
        let state = &mut ctx.accounts.state;
        
        // check if owner try to run this method
        let owner_public_key = Pubkey::from_str(OWNER).unwrap();
        require_keys_eq!(
            ctx.accounts.admin.key(),
            owner_public_key,
            ErrorCode::Unauthorized,
        );

        state.is_paused = true;
        Ok(())
    }

    pub fn unpause(ctx: Context<TogglePause>) -> Result<()> {
        let state = &mut ctx.accounts.state;
        
        // check if owner try to run this method
        let owner_public_key = Pubkey::from_str(OWNER).unwrap();
        require_keys_eq!(
            ctx.accounts.admin.key(),
            owner_public_key,
            ErrorCode::Unauthorized,
        );

        state.is_paused = false;
        Ok(())
    }

    pub fn deposit_to_reward_pool(ctx: Context<DepositToRewardPool>, amount: u64) -> Result<()> {
        // create new instruction for transfer funds
        let ix = system_instruction::transfer(
            &ctx.accounts.user.key(),
            &ctx.accounts.reward_pool.key(),
            amount,
        );

        anchor_lang::solana_program::program::invoke(
            &ix,
            &[
                ctx.accounts.user.to_account_info(),
                ctx.accounts.reward_pool.to_account_info(),
            ]
        )?;

        Ok(())
    }
    
    pub fn distribute_reward(ctx: Context<DistributeReward>, amount: u64) -> Result<()> {
        let state = &ctx.accounts.state;
        let reward_pool_account = &ctx.accounts.reward_pool;

        // check if owner try to run this method
        let owner_public_key = Pubkey::from_str(OWNER).unwrap();
        require_keys_eq!(
            ctx.accounts.admin.key(),
            owner_public_key,
            ErrorCode::Unauthorized,
        );

        // cancel execution if contract is paused
        if state.is_paused {
            return Err(ErrorCode::DistributionPaused.into());
        }

        // check if reward pool has enough sol to may a reward
        let reward_pool_balance = **reward_pool_account.to_account_info().lamports.borrow();
        if reward_pool_balance < amount {
            return Err(ErrorCode::InsufficientFunds.into());
        }

        **ctx.accounts.reward_pool.to_account_info().try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.recipient.to_account_info().try_borrow_mut_lamports()? += amount;
        
        Ok(())
    }
 }

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, seeds = [b"state"], bump, payer = user, space = 8 + 8)]
    pub state: Account<'info, State>,
    #[account(init, seeds = [b"reward_pool"], bump, payer = user, space = 8 + 8)]
    pub reward_pool: Account<'info, RewardPoolAccount>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct TogglePause<'info> {
    #[account(mut)]
    pub state: Account<'info, State>,
    #[account(mut)]
    pub admin: Signer<'info>,
}

#[derive(Accounts)]
pub struct DepositToRewardPool<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    /// CHECK: This is safe because we're sending funds to this account
    #[account(mut, address = *reward_pool.key)]
    pub reward_pool: AccountInfo<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct DistributeReward<'info> {
    #[account(mut)]
    pub state: Account<'info, State>,
    /// CHECK: This is safe because we're sending funds from this account
    #[account(mut)]
    pub reward_pool: Account<'info, RewardPoolAccount>,
    /// CHECK: This is safe because we're sending funds to this account
    #[account(mut)]
    pub recipient: AccountInfo<'info>,
    #[account(mut)]
    pub admin: Signer<'info>,
    pub system_program: Program<'info, System>,

}

#[account]
pub struct RewardPoolAccount {}


#[account]
pub struct State {
    pub is_paused: bool,
}


// Errors:
#[error_code]
pub enum ErrorCode {
    #[msg("Insufficient funds in the reward pool.")]
    InsufficientFunds,
    #[msg("Distribution is paused")]
    DistributionPaused,
    #[msg("Unauthorized access to distribute reward")]
    Unauthorized,
}